import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lock_runtime.dart';
import '../../core/settings.dart';
import 'package:path_provider/path_provider.dart';

import 'package:envx/data/database.dart';
import 'package:envx/data/photo_spot_store.dart';
import 'package:envx/data/schema.dart';
import 'package:envx/ui/theme.dart';
import 'package:envx/ui/widgets/paper_lines.dart';
import 'package:envx/ui/widgets/sticker_photo.dart';

/// M3 信封编辑页（界面稿 05 屏）。
///
/// 数值与规则全部来自 `docs/UI-规格-M3.md`：
/// - 画布底 #DDEEE8，翻折高 52，信纸 padding 24/22/34，圆角 3
/// - 横线周期 28，与正文行盒（14×2.0）严格对齐
/// - 插图 -2.2° 贴纸样式
const double _canvasPad = 20;
const double _letterTop = 24;
const double _letterSide = 22;
const double _letterBottom = 34;
const double _flapHeight = 52;

const Color _canvasBg = Color(0xFFDDEEE8);
const Color _flapTopColor = Color(0xFFCFE5DE);
const Color _flapDashColor = Color(0xFFC2DCD4);
const Color _bodyInk = Color(0xFF2C423B);
const Color _stampBorder = Color(0xFFB9D5CC);
const Color _stampBg = Color(0xFFF6FBF9);

class EnvelopeEditorPage extends StatefulWidget {
  const EnvelopeEditorPage({
    super.key,
    required this.db,
    required this.notebook,
    this.note,
    this.initialPhotos = const [],
    this.decodedPhotos,
    this.initialSpots,
    this.dir,
  });

  final EnvxDatabase db;
  final Notebook notebook;

  /// null 表示新建。
  final Note? note;

  /// 已存于这封信里的图片。null 时会自己从 attachment 表读回（M6-C）。
  final List<File> initialPhotos;

  /// 测试专用：按文件路径预置已解码的图像。
  ///
  /// headless golden 环境里 `Image.file` 的异步解码不会完成，整页截图会得到
  /// 空白白边；传入本表后对应插图改走 `RawImage` 同步绘制，能真实出图。
  /// 真机/正常运行永远不传，仍走 `Image.file`。
  final Map<String, ui.Image>? decodedPhotos;

  /// 测试专用：预置每张图的摆法（真机上从 photo_spots.json 读）。
  final Map<String, PhotoSpot>? initialSpots;

  /// 用来落盘排版设置。从搜索页/测试进来时可能是 null，那就只在本次会话生效。
  final Directory? dir;

  @override
  State<EnvelopeEditorPage> createState() => _EnvelopeEditorPageState();
}

class _EnvelopeEditorPageState extends State<EnvelopeEditorPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final AnimationController _open;

  final List<File> _photos = [];

  /// 每张图的摆法（位置 + 环绕方式）。没有记录的图默认「单独一行」（嵌入型）。
  final Map<String, PhotoSpot> _spots = {};

  /// 用来在拖动开始时读出这张图当前的位置。
  final Map<String, GlobalKey> _photoKeys = {};

  /// 正在被长按拎起来的那张图。
  String? _liftedPath;

  /// 信纸本体，用来把屏幕坐标换算成信纸坐标。
  final GlobalKey _letterKey = GlobalKey();
  bool _dirty = false;

  /// 已落盘的笔记 id。新建的笔记在第一次自动保存时拿到，之后都复用它，
  /// 否则每次自动保存都会再建一条新笔记。
  String? _noteId;

  /// 输入停下后的落盘定时器。
  Timer? _saveTimer;

  /// 正在进行的写库操作，用来把连续触发的保存串成一队。
  Future<void>? _inflight;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.body ?? '');
    _photos.addAll(widget.initialPhotos);
    _noteId = widget.note?.id;
    // 有显式注入就以注入为准（截图用例走这条）；否则从 attachment 表读回。
    if (widget.note != null && widget.initialPhotos.isEmpty) {
      _loadAttachments();
    }
    if (widget.initialSpots != null) {
      // 截图/测试直接给摆法，省掉一次真实 IO（headless 里那个 await 不完成）。
      _spots.addAll(widget.initialSpots!);
    } else {
      _loadSpots();
    }
    _titleCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(_markDirty);
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _open.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    // 实时保存：手停下 700ms 就落盘，不再等用户点「完成」。
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _persist);
  }

  Future<void> _loadSpots() async {
    final dir = widget.dir;
    final noteId = widget.note?.id;
    if (dir == null || noteId == null) return;
    try {
      final all = await PhotoSpotStore(dir: dir).loadAll();
      final spots = all[noteId];
      if (spots == null || spots.isEmpty || !mounted) return;
      setState(() => _spots.addAll(spots));
    } on Object {
      // 位置读不出来就按默认流式排，不影响写。
    }
  }

  RenderBox? get _letterBox {
    final ctx = _letterKey.currentContext;
    if (ctx == null) return null;
    final obj = ctx.findRenderObject();
    return obj is RenderBox ? obj : null;
  }

  PhotoWrap _wrapOf(File f) => _spots[f.path]?.wrap ?? PhotoWrap.inline;

  List<File> get _inlinePhotos =>
      [for (final f in _photos) if (_wrapOf(f) == PhotoWrap.inline) f];

  /// 这张图当前在信纸坐标系里的左上角。流里的图也能算出来，拎起来的瞬间才不会跳。
  Offset _originOf(File f) {
    final box = _letterBox;
    final imgBox = _photoKeys[f.path]?.currentContext?.findRenderObject();
    if (box == null || imgBox is! RenderBox || !imgBox.hasSize) {
      return Offset.zero;
    }
    return box.globalToLocal(imgBox.localToGlobal(Offset.zero));
  }

  /// 手指落点相对图片左上角的偏移，拖动时保持它，图才不会从指下跳走。
  Offset _grab = Offset.zero;

  void _photoDragStart(File f, Offset global) {
    final box = _letterBox;
    if (box == null) return;
    final origin = _originOf(f);
    final local = box.globalToLocal(global);
    setState(() {
      _liftedPath = f.path;
      _grab = local - origin;
      // 拎起来就脱离正文流：默认走「衬于文字下方」，
      // 无论拖到哪一行字上，文字都压在图上面，不会被遮住。
      final wrap = _wrapOf(f) == PhotoWrap.inline ? PhotoWrap.below : _wrapOf(f);
      _spots[f.path] = PhotoSpot(x: origin.dx, y: origin.dy, wrap: wrap);
    });
  }

  void _photoDragUpdate(File f, Offset global) {
    final box = _letterBox;
    final spot = _spots[f.path];
    if (box == null || spot == null) return;
    final local = box.globalToLocal(global);
    final maxX = math.max(-24.0, box.size.width - 40);
    final maxY = math.max(-24.0, box.size.height - 40);
    setState(() {
      _spots[f.path] = spot.copyWith(
        x: (local.dx - _grab.dx).clamp(-24.0, maxX).toDouble(),
        y: (local.dy - _grab.dy).clamp(-24.0, maxY).toDouble(),
      );
    });
  }

  void _photoDragEnd() {
    setState(() => _liftedPath = null);
    _dirty = true;
    _markDirty();
  }

  /// 换这张图的环绕方式：单独一行 / 浮于文字上方 / 衬于文字下方。
  Future<void> _openPhotoWrap(File f) async {
    final cur = _wrapOf(f);
    final chosen = await showModalBottomSheet<PhotoWrap>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '图片怎么放',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: EnvxColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '长按拖动可以把它挪到信纸上的任何位置。',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.2,
                  color: EnvxColors.ink3,
                ),
              ),
              const SizedBox(height: 6),
              _wrapTile(f, cur, PhotoWrap.inline, '单独一行',
                  '占正文里的一行，文字绕开，永远不会挡字'),
              _wrapTile(f, cur, PhotoWrap.below, '衬在文字下方',
                  '图垫在正文下面当底纹；深色图会让字难认，建议挪到空白处'),
              _wrapTile(f, cur, PhotoWrap.above, '浮在文字上方',
                  '图压在最上层，会盖住下面的字'),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (_wrapOf(f) == chosen) return;
    setState(() {
      if (chosen == PhotoWrap.inline) {
        // 回到正文流，坐标就没意义了，清掉。
        _spots.remove(f.path);
      } else {
        final origin = _originOf(f);
        _spots[f.path] =
            PhotoSpot(x: origin.dx, y: origin.dy, wrap: chosen);
      }
    });
    _dirty = true;
    _markDirty();
  }

  Widget _wrapTile(File f, PhotoWrap cur, PhotoWrap value, String title,
      String sub) {
    final on = cur == value;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
        color: on ? EnvxColors.mint700 : EnvxColors.ink3,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
          color: EnvxColors.ink,
        ),
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(fontSize: 12, color: EnvxColors.ink3),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  /// 信纸上的图统一这么建，流里的和浮起来的都一样。
  Widget _photoSlot(File f, {bool showRemove = true}) {
    return _PhotoSlot(
      key: _photoKeys.putIfAbsent(f.path, () => GlobalKey()),
      file: f,
      decoded: widget.decodedPhotos?[f.path],
      lifted: _liftedPath == f.path,
      showRemove: showRemove,
      onLiftStart: (g) => _photoDragStart(f, g),
      onLiftMove: (g) => _photoDragUpdate(f, g),
      onLiftEnd: _photoDragEnd,
      onTap: () => _openPhotoWrap(f),
      onRemove: () => _removePhoto(f),
    );
  }

  /// 从 attachment 表读回这封信的插图；文件已被外部删掉的就跳过。
  Future<void> _loadAttachments() async {
    final note = widget.note;
    if (note == null) return;
    final rows = await widget.db.attachments.listFor(note.id);
    final files = <File>[];
    for (final row in rows) {
      final f = File(row.path);
      if (await f.exists()) files.add(f);
    }
    if (!mounted) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(files);
    });
  }

  Future<void> _removePhoto(File photo) async {
    _spots.remove(photo.path);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        title: const Text('删掉这张图？'),
        content: const Text('点完成之后，这封信里就不再显示它。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() {
      _photos.remove(photo);
      _dirty = true;
    });
  }

  String _metaLine() {
    final ms = widget.note?.updatedAt ??
        DateTime.now().millisecondsSinceEpoch;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}月${dt.day}日 · ${widget.notebook.name}';
  }

  /// 把当前内容落盘，但不退出页面。
  Future<void> _doPersist() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text;
    // 一个字没写、一张图没加，就不要凭空建一条空笔记。
    if (_noteId == null &&
        title.isEmpty &&
        body.trim().isEmpty &&
        _photos.isEmpty) {
      return;
    }

    try {
      final String noteId;
      if (_noteId == null) {
        final created = await widget.db.notes.create(
          notebookId: widget.notebook.id,
          title: title.isEmpty ? null : title,
          body: body,
        );
        _noteId = created.id;
        noteId = created.id;
      } else {
        await widget.db.notes.save(_noteId!, title: title, body: body);
        noteId = _noteId!;
      }
      await widget.db.attachments.replaceFor(
        noteId,
        _photos.map((f) => f.path).toList(),
      );
      final dir = widget.dir;
      if (dir != null && _spots.isNotEmpty) {
        try {
          // 只存水平对齐（-1..1），不存纵坐标：位置跟正文高度解耦，
          // 正文写长了也不会把图压住。
          await PhotoSpotStore(dir: dir).save(noteId, _spots);
        } on Object {
          // 位置存不住不影响正文，下次打开按默认排。
        }
      }
      _dirty = false;
    } finally {
      // 保存态已经不上界面了（顶栏「完成」已删），这里不必再触发重建。
    }
  }

  /// 串行化保存：上一次还在写库时又触发了，就排在它后面再存一次，
  /// 否则两次写库会互相盖掉。
  Future<void> _persist() {
    final inflight = _inflight;
    if (inflight != null) {
      return inflight.then((_) => _persist());
    }
    final fut = _doPersist();
    _inflight = fut;
    return fut.whenComplete(() {
      if (identical(_inflight, fut)) _inflight = null;
    });
  }

  Future<void> _back() async {
    // 内容已经实时保存了，返回不该再问「要不要放弃」：既没有可放弃的东西，
    // 问一遍反而像在暗示内容会丢。
    _saveTimer?.cancel();
    await _persist();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickPhoto() async {
    // 不带 maxWidth / imageQuality：那两项会让 image_picker 重新编码，
    // 拍摄时间、机型、GPS 等 EXIF 全部丢失。用户明确要求保留 EXIF，
    // 所以这里按原图直接复制，压缩交给日后的缩略图流程。
    //
    // 相册是外部 Activity：拉起前后必须豁免全局锁，否则选完图回来会被
    // 判成「切过后台」而盖上锁屏 —— 图片插不进正文，用户只会看到「已上锁」。
    LockRuntime.beginExternalUi();
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } finally {
      LockRuntime.endExternalUi();
    }
    if (picked == null) return;

    // 相册返回的是临时文件，复制进应用目录，否则重启后路径失效。
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docs.path}/envx_photos');
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final copied = await File(picked.path).copy(
      '${photosDir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
    );

    if (!mounted) return;
    setState(() {
      _photos.add(copied);
      _dirty = true;
    });
  }

  /// 把设置写进内存快照，再落盘。
  /// 编辑页可能没有 dir（测试、从搜索页进），那就只在本次会话生效。
  Future<void> _applySettings(AppSettings next) async {
    SettingsRuntime.value = next;
    final dir = widget.dir;
    if (dir == null) return;
    try {
      await SettingsStore(dir: dir).save(next);
    } on Object {
      // 存不下去就算了，界面已经按新值刷新，不打断写作。
    }
  }

  /// 排版：字号 / 行距。横线周期跟着一起变，不会错行。
  Future<void> _openTypography() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EnvxColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final s = SettingsRuntime.value;

          Widget chip(String label, bool on, VoidCallback tap) {
            return GestureDetector(
              onTap: tap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? EnvxColors.mint100 : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: on ? EnvxColors.mint700 : const Color(0xFFE6EFEA),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.2,
                    color: on ? EnvxColors.mint700 : EnvxColors.ink2,
                  ),
                ),
              ),
            );
          }

          Widget row(String label, List<Widget> chips) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: EnvxColors.ink2,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < chips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: chips[i]),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }

          Future<void> pick(AppSettings next) async {
            await _applySettings(next);
            if (!mounted) return;
            setState(() {});
            setSheet(() {});
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E7E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '排版',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: EnvxColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '行高 ${s.bodyLineBox.toStringAsFixed(0)}　·　信纸横线跟着一起调',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: EnvxColors.ink3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  row('字号', [
                    for (final v in const [13.0, 14.0, 16.0])
                      chip(
                        v == 14.0 ? '标准 14' : '${v.toInt()}',
                        s.bodySize == v,
                        () => pick(s.copyWith(bodySize: v)),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  row('行距', [
                    chip('紧凑', s.bodyHeight == 1.75,
                        () => pick(s.copyWith(bodyHeight: 1.75))),
                    chip('标准', s.bodyHeight == 2.0,
                        () => pick(s.copyWith(bodyHeight: 2.0))),
                    chip('宽松', s.bodyHeight == 2.25,
                        () => pick(s.copyWith(bodyHeight: 2.25))),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6EFEA)),
                    ),
                    child: Text(
                      '今天想写点什么…\n这一行是你现在的排版，落笔前先看一眼。',
                      style: TextStyle(
                        fontSize: s.bodySize,
                        height: s.bodyHeight,
                        letterSpacing: 0.28,
                        color: EnvxColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _canvasArea()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_canvasPad, 4, _canvasPad, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              key: const ValueKey('editor-back'),
              onTap: _back,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  // 和笔记本列表页用同一个返回箭头，别两处两种画风。
                  child: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: EnvxColors.ink,
                  ),
                ),
              ),
            ),
            Text(
              _metaLine(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.44,
                color: EnvxColors.ink3,
              ),
            ),
            // 「完成」已删：正文 700ms 防抖自动落盘，返回即保存，
            // 右上角再放一个同名按钮只是重复。留等宽占位，中间那行日期才居中。
            const SizedBox(width: 32, height: 32),
          ],
        ),
      ),
    );
  }

  Widget _canvasArea() {
    return AnimatedBuilder(
      animation: _open,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_open.value.clamp(0.0, 1.0));
        return Stack(
          children: [
            // 信封盖常驻 52 高，压在信纸下层（设计稿 .flap 先于 .letter 声明）。
            // 可见的就是信纸上方露出的那一条渐变 + 边缘虚线，随开封动效淡入。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _flapHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: t,
                  child: CustomPaint(
                    painter: const _FlapPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // 信纸至少占满可视区：短笔记不该在下面露出一大片桌面。
                // 内容超过一屏后，由 SingleChildScrollView 接管，高度跟着内容走。
                // 14 是上边距，16 是下边距：信纸底部别贴着底栏，留一口气。
                final minH = math.max(0.0, constraints.maxHeight - 14 - 16);
                return Padding(
                  padding:
                      const EdgeInsets.fromLTRB(_canvasPad, 14, _canvasPad, 16),
                  child: Transform.translate(
                    offset: Offset(0, -18 * (1 - t)),
                    child: SingleChildScrollView(
                      child: _letter(minHeight: minH),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _letter({double minHeight = 0}) {
    return Container(
      key: _letterKey,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF175F55).withValues(alpha: 0.55),
            offset: const Offset(0, 12),
            blurRadius: 26,
            spreadRadius: -16,
          ),
        ],
      ),
      child: Stack(
        // 贴纸可以压到信纸边缘外一点点，别被 Stack 硬裁。
        clipBehavior: Clip.none,
        children: [
          if (SettingsRuntime.value.paperLines)
            Positioned.fill(
              child: CustomPaint(
                painter: PaperLinesPainter(
                  contentTop: _letterTop,
                  horizontalInset: _letterSide,
                  period: SettingsRuntime.value.bodyLineBox,
                ),
              ),
            ),
          // 衬于文字下方：垫在正文之下，字压在图上看，不会被遮。
          for (final f in _photos)
            if (_wrapOf(f) == PhotoWrap.below)
              _floatingPhoto(f, showRemove: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _letterSide,
              _letterTop,
              _letterSide,
              _letterBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleField(),
                const SizedBox(height: 14),
                _bodyField(),
                // 嵌入型（单独一行）：占正文流的一行，文字自然绕开。
                for (final f in _inlinePhotos) ...[
                  const SizedBox(height: 14),
                  _photoSlot(f),
                ],
              ],
            ),
          ),
          // 浮于文字上方：压在最上层，Word 同款语义（会盖住字）。
          for (final f in _photos)
            if (_wrapOf(f) == PhotoWrap.above) _floatingPhoto(f),
          // 衬在文字下方的图被正文盖住了，它的「挪位置 / 删除」按钮得单独放在上
          // 层，否则点了永远是正文接管，图再也选不中（用户踩到的死点）。
          for (final f in _photos)
            if (_wrapOf(f) == PhotoWrap.below) _belowTools(f),
          const Positioned(top: 14, right: 16, child: _Stamp()),
        ],
      ),
    );
  }

  Widget _floatingPhoto(File f, {bool showRemove = true}) {
    final spot = _spots[f.path];
    if (spot == null) return const SizedBox.shrink();
    return Positioned(
      left: spot.x,
      top: spot.y,
      child: _photoSlot(f, showRemove: showRemove),
    );
  }

  /// 衬于文字下方的图：本体在正文下层点不到，所以把「拿起来挪」和「删除」
  /// 两个小钮画在最上层，贴着图的两个角。
  Widget _belowTools(File f) {
    final spot = _spots[f.path];
    if (spot == null) return const SizedBox.shrink();
    return Positioned(
      left: spot.x + 6,
      top: spot.y + 6,
      child: Row(
        children: [
          GestureDetector(
            key: ValueKey('photo-move-${f.path}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPhotoWrap(f),
            onLongPressStart: (d) => _photoDragStart(f, d.globalPosition),
            onLongPressMoveUpdate: (d) => _photoDragUpdate(f, d.globalPosition),
            onLongPressEnd: (_) => _photoDragEnd(),
            child: const _PhotoTool(icon: Icons.open_with),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: ValueKey('photo-del-${f.path}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _removePhoto(f),
            child: const _PhotoTool(icon: Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleCtrl,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        height: 1.5,
        letterSpacing: 0.63,
        color: EnvxColors.ink,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: '给这封信起个名字',
        hintStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: EnvxColors.ink3,
        ),
      ),
      cursorColor: EnvxColors.mint500,
    );
  }

  Widget _bodyField() {
    final s = SettingsRuntime.value;
    final size = s.bodySize;
    final height = s.bodyHeight;
    return TextField(
      controller: _bodyCtrl,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: TextStyle(
        fontSize: size,
        height: height,
        letterSpacing: 0.28,
        color: _bodyInk,
      ),
      // forceStrutHeight 让每一行盒严格等于 size × height，横线才能对得上。
      strutStyle: StrutStyle(
        fontSize: size,
        height: height,
        leading: 0,
        forceStrutHeight: true,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: '今天想写点什么…',
        hintStyle: TextStyle(
          fontSize: size,
          height: height,
          color: EnvxColors.ink3,
        ),
      ),
      cursorColor: EnvxColors.mint500,
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: EnvxColors.paper,
        border: Border(top: BorderSide(color: EnvxColors.mint100, width: 1)),
      ),
      child: Row(
        // 只剩两个按钮，居中并排比 spaceAround 更聚拢。
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _barButton(
            const _BarIcon(_BarKind.typewriter),
            _openTypography,
            keyName: 'editor-typography',
          ),
          const SizedBox(width: 48),
          _barButton(
            const _BarIcon(_BarKind.image),
            _pickPhoto,
            keyName: 'editor-photo',
          ),
          // 这里原来有一个信封图标，作用和顶栏「完成」一样：存完就 pop。
          // 用户实测说它「点击相当于返回键」，看不懂，已删。
        ],
      ),
    );
  }

  Widget _barButton(Widget icon, VoidCallback onTap, {String? keyName}) {
    return GestureDetector(
      key: keyName == null ? null : ValueKey(keyName),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 54,
        child: Center(child: icon),
      ),
    );
  }
}

/// 底栏图标：按界面稿的 SVG 路径自绘，不用 Material Icons（形状对不上）。
enum _BarKind { typewriter, image, checklist, envelope }

class _BarIcon extends StatelessWidget {
  const _BarIcon(this.kind);

  final _BarKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _BarIconPainter(kind, EnvxColors.ink),
    );
  }
}

class _BarIconPainter extends CustomPainter {
  const _BarIconPainter(this.kind, this.color);

  final _BarKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 22.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (kind) {
      case _BarKind.typewriter:
        // 三条宽度递减的正文行。原来右边那个「>」像按钮箭头，
        // 和「返回 / 更多」混在一起，删掉。
        for (final row in const [(16.0, 6.0), (16.0, 11.0), (10.0, 16.0)]) {
          canvas.drawLine(
            Offset(3, row.$2) * s,
            Offset(3 + row.$1, row.$2) * s,
            stroke,
          );
        }
        break;

      case _BarKind.image:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2.6 * s, 4 * s, 16.8 * s, 14 * s),
            Radius.circular(2.4 * s),
          ),
          stroke,
        );
        canvas.drawCircle(Offset(8, 9) * s, 1.7 * s, fill);
        canvas.drawPath(
          Path()
            ..moveTo(3.4 * s, 16 * s)
            ..lineTo(8 * s, 11 * s)
            ..lineTo(11.6 * s, 15 * s)
            ..lineTo(14.2 * s, 12.6 * s)
            ..lineTo(18 * s, 16 * s),
          stroke,
        );
        break;

      case _BarKind.checklist:
        // 小方框 + 短线。原来那条线加圆点压在一起，看着像一串虚线。
        for (final y in const [6.0, 11.0, 16.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(3 * s, (y - 2.2) * s, 4.4 * s, 4.4 * s),
              Radius.circular(1.2 * s),
            ),
            stroke,
          );
          canvas.drawLine(Offset(10, y) * s, Offset(18, y) * s, stroke);
        }
        break;

      case _BarKind.envelope:
        final k = size.width / 24.0;
        final thin = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2.5 * k, 6 * k, 19 * k, 13 * k),
            Radius.circular(2 * k),
          ),
          thin,
        );
        canvas.drawPath(
          Path()
            ..moveTo(2.5 * k, 7 * k)
            ..lineTo(12 * k, 14 * k)
            ..lineTo(21.5 * k, 7 * k),
          thin,
        );
        canvas.drawCircle(Offset(12, 14) * k, 2.2 * k, Paint()..color = color);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BarIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// 顶栏返回箭头：18×18 折线，描边 1.6，圆角端点（对齐设计稿 SVG）。
/// 信封上盖：竖向渐变 + 底部虚线。
class _FlapPainter extends CustomPainter {
  const _FlapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_flapTopColor, _canvasBg],
          stops: [0.0, 0.78],
        ).createShader(rect),
    );

    final dash = Paint()
      ..color = _flapDashColor
      ..strokeWidth = 1;
    final y = size.height - 0.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        dash,
      );
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _FlapPainter oldDelegate) => false;
}

/// 右上角邮票：38×46 虚线框 + 18×18 信封线稿。
class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 46,
      color: _stampBg,
      child: const CustomPaint(painter: _StampPainter()),
    );
  }
}

class _StampPainter extends CustomPainter {
  const _StampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = _stampBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 虚线外框
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 4, size.width), 0.5), border);
      canvas.drawLine(
        Offset(x, size.height - 0.5),
        Offset(math.min(x + 4, size.width), size.height - 0.5),
        border,
      );
      x += 7;
    }
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, math.min(y + 4, size.height)), border);
      canvas.drawLine(
        Offset(size.width - 0.5, y),
        Offset(size.width - 0.5, math.min(y + 4, size.height)),
        border,
      );
      y += 7;
    }

    // 信封图标
    final icon = Paint()
      ..color = EnvxColors.mint500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final rect = Rect.fromLTWH(
      size.width / 2 - 9,
      size.height / 2 - 5,
      18,
      10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.6)),
      icon,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + 0.6)
        ..lineTo(rect.center.dx, rect.top + 6)
        ..lineTo(rect.right, rect.top + 0.6),
      icon,
    );
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) => false;
}

/// 信纸上的一张插图。长按拖动可以挪到任意位置，点一下换环绕方式，
/// 右上角「×」删除。
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    super.key,
    required this.file,
    required this.onLiftStart,
    required this.onLiftMove,
    required this.onLiftEnd,
    required this.onRemove,
    required this.onTap,
    this.decoded,
    this.lifted = false,
    this.showRemove = true,
  });

  final File file;
  final ui.Image? decoded;
  final bool lifted;
  final bool showRemove;
  final void Function(Offset global) onLiftStart;
  final void Function(Offset global) onLiftMove;
  final VoidCallback onLiftEnd;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (d) => onLiftStart(d.globalPosition),
      onLongPressMoveUpdate: (d) => onLiftMove(d.globalPosition),
      onLongPressEnd: (_) => onLiftEnd(),
      child: AnimatedOpacity(
        opacity: lifted ? 0.28 : 1,
        duration: const Duration(milliseconds: 140),
        child: _PhotoChrome(
          file: file,
          decoded: decoded,
          showRemove: showRemove,
          onRemove: onRemove,
        ),
      ),
    );
  }
}

/// 图 + 右上角删除角标。嵌入型和浮动型共用，样式才一致。
class _PhotoChrome extends StatelessWidget {
  const _PhotoChrome({
    required this.file,
    required this.onRemove,
    this.decoded,
    this.showRemove = true,
  });

  final File file;
  final ui.Image? decoded;
  final bool showRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        StickerPhoto(file: file, decoded: decoded),
        // 角标压在图上，够得着；原来挂在图外侧 8px，看着像另一个元素。
        if (showRemove)
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xF2FFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33000000), width: 0.5),
              ),
              child: const Icon(Icons.close, size: 13, color: EnvxColors.ink2),
            ),
          ),
        ),
      ],
    );
  }
}

/// 浮在正文上层的小圆钮（挪位置 / 删除），保证「衬在文字下方」的图也选得中。
class _PhotoTool extends StatelessWidget {
  const _PhotoTool({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33000000), width: 0.5),
      ),
      child: Icon(icon, size: 14, color: EnvxColors.ink2),
    );
  }
}
