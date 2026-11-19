import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/lan_node.dart';
import '../../data/database.dart';
import '../../data/lan_transfer.dart';
import '../../data/schema.dart';
import '../theme.dart';

/// 08 屏 · 局域网互传。
/// 一层页：上面是本机配对码（别人照这个码才能推东西给你），下面是同一 WiFi 里
/// 发现到的其他设备。点一台设备 → 选一本笔记本 → 寄过去；对方那边会自动落库。
class LanTransferPage extends StatefulWidget {
  const LanTransferPage({
    super.key,
    required this.db,
    required this.dir,
    this.code,
    this.localAddr,
  });

  /// 指定配对码。只给截图测试用 —— 真实运行时留空，每次进页面新生成。
  final String? code;

  /// 指定本机地址。同理只给截图测试用：golden 里的 IP 和端口会随机器
  /// 与网络变化，钉死一个值才能让截图可比。
  final String? localAddr;

  final EnvxDatabase db;

  /// 应用数据目录，用来定位图片落盘位置。
  final Directory dir;

  @override
  State<LanTransferPage> createState() => _LanTransferPageState();
}

class _LanTransferPageState extends State<LanTransferPage> {
  static const _cardLine = Color(0xFFD8E8E3);

  late final String _code;
  LanNode? _node;
  StreamSubscription<List<LanPeerInfo>>? _sub;
  List<LanPeerInfo> _peers = const [];
  bool _busy = false;
  String? _status;

  /// 本机在局域网里的「IP:端口」。显示出来是为了让对面能手动输 ——
  /// 有些路由器隔离多播，自动发现永远空着，但 HTTP 直连是通的。
  String? _localAddr;

  @override
  void initState() {
    super.initState();
    _code = widget.code ?? newPairCode();
    _photosDir = '${widget.dir.path}${Platform.pathSeparator}photos';
    if (widget.localAddr != null) _localAddr = widget.localAddr;
    _boot();
  }

  String _photosDir = '';

  Future<void> _boot() async {
    final node = LanNode(
      code: _code,
      deviceName: Platform.isAndroid ? '安卓设备' : '这台设备',
      photosDir: _photosDir,
    );
    node.onPackReceived = _onReceive;
    try {
      await node.start();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _status = '没能打开局域网服务：$e');
      }
      return;
    }
    if (!mounted) {
      await node.dispose();
      return;
    }
    _node = node;
    _sub = node.peers.listen((list) {
      if (mounted) setState(() => _peers = list);
    });
    await _resolveLocalAddr(node);
    setState(() {});
  }

  Future<void> _resolveLocalAddr(LanNode node) async {
    // 截图测试注入了固定值，就别再拿真实网卡覆盖它 —— 否则 golden 会
    // 随机器和网络漂移。
    if (widget.localAddr != null) return;
    final port = node.httpPort;
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final i in ifaces) {
        for (final a in i.addresses) {
          // 只取 IPv4 私网地址；虚拟网卡常是 169.254.x.x，跳过
          if (a.isLoopback) continue;
          if (a.address.startsWith('169.254.')) continue;
          if (mounted) {
            setState(() => _localAddr = '${a.address}:$port');
          }
          return;
        }
      }
    } on Object {
      // 拿不到就不显示 —— 自动发现那条路仍然是可用的，不必因为
      // 一个辅助信息缺失就报错。
    }
  }

  Future<void> _onReceive(String packJson, String from) async {
    final pack = parsePack(packJson);
    final result = await applyPack(
      db: widget.db,
      pack: pack,
      photosDir: _photosDir,
    );
    final text = StringBuffer('收到来自「$from」的《${pack.notebookName}》');
    text.write('，${result.noteCount} 封');
    if (result.photoCount > 0) text.write('、${result.photoCount} 张图');
    if (result.badPhotos > 0) text.write('（${result.badPhotos} 张图校验不过，已跳过）');
    if (mounted) setState(() => _status = text.toString());
  }

  Future<void> _sendTo(LanPeerInfo peer) async {
    if (_busy) return;
    final notebooks = await widget.db.notebooks.all();
    if (!mounted) return;
    if (notebooks.isEmpty) {
      setState(() => _status = '本机还没有笔记本，先写一本再来');
      return;
    }
    final picked = await showModalBottomSheet<Notebook>(
      context: context,
      backgroundColor: EnvxColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _NotebookPicker(notebooks: notebooks, peerName: peer.name),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = '正在寄给「${peer.name}」…';
    });
    try {
      final pack = await buildPack(db: widget.db, notebook: picked);
      final err = await _node!.pushTo(peer, pack.json);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = err ??
            '已寄出《${pack.noteCount} 封 / ${pack.photoCount} 张图》给「${peer.name}」';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '寄送失败：$e';
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    final node = _node;
    _node = null;
    if (node != null) unawaited(node.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnvxColors.mist,
      body: SafeArea(
        // 整个页面统一限宽 600 居中（含标题栏），否则平板下标题贴左、
        // 内容居中，两块对不齐。
        child: LayoutBuilder(
          builder: (context, page) {
            final side = page.maxWidth > 640 ? (page.maxWidth - 600) / 2 : 0.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 + side, 6, 20 + side, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                    color: EnvxColors.ink,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '局域网互传',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: EnvxColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24 + side, 2, 24 + side, 0),
              child: Text(
                '仅同一 WiFi · 不经过任何服务器',
                style: TextStyle(
                  fontSize: 11,
                  color: EnvxColors.ink3,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24 + side, 18, 24 + side, 24),
                children: [
                  _codeCard(),
                  if (_status != null) ...[
                    const SizedBox(height: 14),
                    _statusBar(),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    '同一 WiFi 里的设备',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: EnvxColors.ink3,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_peers.isEmpty) _emptyPeers() else _peerList(),
                  const SizedBox(height: 8),
                  _manualRow(),
                  const SizedBox(height: 18),
                  _steps(),
                  const SizedBox(height: 18),
                  _hint(),
                ],
              ),
            ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _codeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: EnvxColors.paper,
        border: Border.all(color: _cardLine),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_tethering_rounded, size: 30, color: EnvxColors.mint700),
          const SizedBox(height: 10),
          Text(
            '让对面输入这个码',
            style: TextStyle(fontSize: 12, color: EnvxColors.ink2, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            _code.split('').join(' '),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: EnvxColors.mint700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '接受一次传输后建议退出去重进，码会换新的',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: EnvxColors.ink3, height: 1.7),
          ),
          if (_localAddr != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: EnvxColors.mint100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '本机地址 $_localAddr',
                style: TextStyle(
                  fontSize: 11,
                  color: EnvxColors.mint700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: EnvxColors.mint100,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        _status!,
        style: TextStyle(fontSize: 12, color: EnvxColors.mint700, height: 1.6),
      ),
    );
  }

  Widget _emptyPeers() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: EnvxColors.paper,
        border: Border.all(color: _cardLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '还在找…',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: EnvxColors.ink2),
          ),
          const SizedBox(height: 6),
          Text(
            '两台设备都停在局域网互传这一页，且连同一个 WiFi，就会互相出现',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: EnvxColors.ink3, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _peerList() {
    return Column(
      children: [
        for (final peer in _peers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: EnvxColors.paper,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy ? null : () => _sendTo(peer),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: _cardLine),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.smartphone_rounded, size: 20, color: EnvxColors.mint500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.name,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: EnvxColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              peer.host,
                              style: TextStyle(fontSize: 10, color: EnvxColors.ink3),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '寄一本',
                        style: TextStyle(fontSize: 11.5, color: EnvxColors.mint700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _manualRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _busy ? null : _manualConnect,
        icon: Icon(Icons.link_rounded, size: 16, color: EnvxColors.mint700),
        label: Text(
          '找不到？手动输入对方地址',
          style: TextStyle(fontSize: 12, color: EnvxColors.mint700),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// 手动通道：照抄对面「本机地址」那行 + 对方 6 位码。
  /// 为什么需要这两个值：地址用来直连（绕开被隔离的 UDP 广播），
  /// 码用来让对方校验"确实是认识的人要传"。
  Future<void> _manualConnect() async {
    final addr = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EnvxColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '手动连接',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnvxColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '把对面页面上「本机地址」那行照抄过来，再填对方 6 位码。',
              style: TextStyle(fontSize: 12, color: EnvxColors.ink2, height: 1.7),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: addr,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '192.168.1.5:39481',
                labelText: '对方地址',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 13, letterSpacing: 2),
              decoration: const InputDecoration(
                hintText: '6 位数字',
                labelText: '对方配对码',
                isDense: true,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: EnvxColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('连接', style: TextStyle(color: EnvxColors.mint700)),
          ),
        ],
      ),
    );

    final rawAddr = addr.text;
    final rawCode = code.text.trim();
    addr.dispose();
    code.dispose();
    if (ok != true || !mounted) return;

    final parsed = parseManualEndpoint(rawAddr);
    if (parsed == null) {
      setState(() => _status = '地址格式不对，写成 192.168.1.5:39481 这样');
      return;
    }
    if (rawCode.length != 6) {
      setState(() => _status = '配对码应该是 6 位数字');
      return;
    }

    await _sendTo(
      LanPeerInfo(
        code: rawCode,
        name: parsed.host,
        host: parsed.host,
        port: parsed.port,
        lastSeen: DateTime.now(),
      ),
    );
  }

  /// 三步说明。这不是装饰 —— 这个页面第一次进来的人都会问
  /// 「然后呢」，两张卡之间空着一大片而没有下一步，是真的缺信息。
  Widget _steps() {
    const items = [
      ('两台都打开这一页', '并且连同一个 WiFi，不连热点也行'),
      ('把上面的 6 位数念给对方', '对面点「加入」后输进去'),
      ('在列表里点那台设备', '找不到就用上面的手动地址，再选一本要寄的笔记本'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '怎么用',
          style: TextStyle(
            fontSize: 10.5,
            color: EnvxColors.ink3,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EnvxColors.mint100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: EnvxColors.mint700,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: EnvxColors.ink,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: EnvxColors.ink3,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hint() {
    return Text(
      '传输只在你和对面之间直连，不经过路由器以外的任何地方。\n'
      '开始传之前确认对面那台就是你要给的人。',
      style: TextStyle(fontSize: 10.5, color: EnvxColors.ink3, height: 1.9),
    );
  }
}

/// 选一本要寄出去的笔记本。
class _NotebookPicker extends StatelessWidget {
  const _NotebookPicker({required this.notebooks, required this.peerName});

  final List<Notebook> notebooks;
  final String peerName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '寄给「$peerName」',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: EnvxColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              '选一本，连信带图一起过去',
              style: TextStyle(fontSize: 11, color: EnvxColors.ink3),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final nb in notebooks)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.mail_outline_rounded, color: EnvxColors.mint500),
                      title: Text(
                        nb.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EnvxColors.ink),
                      ),
                      onTap: () => Navigator.of(context).pop(nb),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
