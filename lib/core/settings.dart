import 'dart:convert';
import 'dart:io';

/// 默认的「笔记本」称呼。用户可在设置里改（我的 + 名词）。
const String kDefaultNoun = '笔记本';

/// 默认信封配色方案 key。
const String kDefaultCoverScheme = 'mist';

/// 默认主题色 key，见 `ThemePreset`。
const String kDefaultTheme = 'mist';

/// 自定义信封三色的默认值（暖沙），顺序对应 sun / sky / blush。
const List<int> kDefaultCustomCover = [
  0xFFF7E4C2,
  0xFFE6DAC6,
  0xFFF2D9CE,
];

/// 应用设置。存成应用目录下的 `settings.json` —— 它不含任何密码或密钥，
/// 只是一组开关，所以不放进加密库，避免开锁前读不到。
class AppSettings {
  const AppSettings({
    this.biometricUnlock = false,
    this.lockOnBackground = true,
    this.screenshotProtect = true,
    this.paperLines = true,
    this.cloudBackup = false,
    this.noun = kDefaultNoun,
    this.coverScheme = kDefaultCoverScheme,
    this.customCover = kDefaultCustomCover,
    this.themeKey = kDefaultTheme,
    this.bodySize = 14.0,
    this.bodyHeight = 2.0,
  });

  final bool biometricUnlock;
  final bool lockOnBackground;
  final bool screenshotProtect;
  final bool paperLines;
  final bool cloudBackup;

  /// 首页标题的名词部分：「我的」+ 名词。默认「笔记本」，
  /// 用户可以改成「卡路里」这类自己更习惯的说法。
  final String noun;

  /// 信封封面配色方案 key，见 `CoverPalette.schemes`。
  final String coverScheme;

  /// 自定义方案的三色（0xAARRGGBB，顺序 sun / sky / blush）。
  final List<int> customCover;

  /// 主题色 key，见 `kThemePresets`。
  final String themeKey;

  /// 正文排版：字号与行距倍数。行盒 = bodySize × bodyHeight，
  /// 信纸横线的周期必须取同一个值，否则字会浮在线中间。
  final double bodySize;
  final double bodyHeight;

  /// 单行行盒高度（= 横线周期）。
  double get bodyLineBox => bodySize * bodyHeight;

  /// 标题文案。名词被清空时回落默认，避免出现「我的 」。
  String get title => '我的${noun.trim().isEmpty ? kDefaultNoun : noun.trim()}';

  AppSettings copyWith({
    bool? biometricUnlock,
    bool? lockOnBackground,
    bool? screenshotProtect,
    bool? paperLines,
    bool? cloudBackup,
    String? noun,
    String? coverScheme,
    List<int>? customCover,
    String? themeKey,
    double? bodySize,
    double? bodyHeight,
  }) {
    return AppSettings(
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      lockOnBackground: lockOnBackground ?? this.lockOnBackground,
      screenshotProtect: screenshotProtect ?? this.screenshotProtect,
      paperLines: paperLines ?? this.paperLines,
      cloudBackup: cloudBackup ?? this.cloudBackup,
      noun: noun ?? this.noun,
      coverScheme: coverScheme ?? this.coverScheme,
      customCover: customCover ?? this.customCover,
      themeKey: themeKey ?? this.themeKey,
      bodySize: bodySize ?? this.bodySize,
      bodyHeight: bodyHeight ?? this.bodyHeight,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      biometricUnlock: json['biometricUnlock'] as bool? ?? false,
      lockOnBackground: json['lockOnBackground'] as bool? ?? true,
      screenshotProtect: json['screenshotProtect'] as bool? ?? true,
      paperLines: json['paperLines'] as bool? ?? true,
      cloudBackup: json['cloudBackup'] as bool? ?? false,
      noun: json['noun'] as String? ?? kDefaultNoun,
      coverScheme: json['coverScheme'] as String? ?? kDefaultCoverScheme,
      customCover: (json['customCover'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList(growable: false) ??
          kDefaultCustomCover,
      themeKey: json['themeKey'] as String? ?? kDefaultTheme,
      bodySize: (json['bodySize'] as num?)?.toDouble() ?? 14.0,
      bodyHeight: (json['bodyHeight'] as num?)?.toDouble() ?? 2.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'biometricUnlock': biometricUnlock,
        'lockOnBackground': lockOnBackground,
        'screenshotProtect': screenshotProtect,
        'paperLines': paperLines,
        'cloudBackup': cloudBackup,
        'noun': noun,
        'coverScheme': coverScheme,
        'customCover': customCover,
        'themeKey': themeKey,
        'bodySize': bodySize,
        'bodyHeight': bodyHeight,
      };
}

/// 运行时快照。编辑页手里只有 `db` 没有 `dir`，却要知道「信纸横线」开没开，
/// 所以这里留一份内存副本：应用进入主区时读盘写入，设置页每次改动同步更新。
class SettingsRuntime {
  SettingsRuntime._();

  static AppSettings value = const AppSettings();
}

/// 读文件损坏或缺失时一律回落到默认值，不让开关状态把应用卡住。
class SettingsStore {
  SettingsStore({required this.dir});

  final Directory dir;

  File get _file => File('${dir.path}/settings.json');

  Future<AppSettings> load() async {
    try {
      if (!await _file.exists()) return const AppSettings();
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings value) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(value.toJson()), flush: true);
    if (await _file.exists()) await _file.delete();
    await tmp.rename(_file.path);
  }
}
