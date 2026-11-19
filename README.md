# 信封日记（envx）

本地优先的加密日记 App。数据只存在这台设备上，写信封、收进笔记本、上锁、互传，全部离线完成。

- 应用包名：`com.envx.envx`
- 技术栈：Flutter 3.50 / Dart 3.14、drift + sqlite3mc（加密库）、Argon2id（口令派生）

## 现在能做什么

| 能力 | 说明 |
| --- | --- |
| 免密启动 | 没设过访问密码时打开即进「我的笔记本」；设了才要求解锁 |
| 笔记本 | 新建 / 重命名 / 删除；点中间空白区新建；整本可搬进隐藏区，也能搬回来 |
| 信封（笔记） | 标题 + 正文，停手 700ms 自动落盘，返回即保存，不需要点「完成」 |
| 排版 | 字号（13 / 14 / 16）、行距（紧凑 / 标准 / 宽松），信纸横线跟着走 |
| 插图 | 相册选图；长按拖到信纸任意位置；三种环绕：单独一行 / 衬在文字下方 / 浮在文字上方 |
| 隐藏区 | 第二密码；独立 `vault.db`；主区与隐藏区互不串数据 |
| 搜索 | 跨笔记本搜标题与正文，输入即搜（防抖 200ms） |
| 备份 | 整库 + 插图快照到外部备份目录；可从备份还原（旧库自动封存，不删） |
| 局域网互传 | 同一 WiFi 直连，按笔记本传输，码校验 |
| 外观 | 信封配色（四套 + 三色自定义）、四套主题色、信纸横线开关、首页标题名词可改 |
| 安全 | 切后台即上锁、截屏/录屏保护（FLAG_SECURE） |

## 数据与加密

- 每个库都是 sqlite3mc 加密文件：`PRAGMA key = "x'<64 hex>'"`，不做二次 KDF。
- 盐是库外 sidecar：`app.db.salt` / `vault.db.salt`。
- 免密模式下密钥是随机 32 字节，存在 `app.db.devicekey`（应用私有目录，系统沙箱保护）。用户后来设了访问密码，用 `PRAGMA rekey` **就地**换密钥，数据一行不动。
- 库在 `getApplicationSupportDirectory()`，插图在 `getApplicationDocumentsDirectory()/photos`。
- 备份目录里有解密钥匙，整份拷走可换机恢复，但**不要外发**。

## 目录

```
lib/
  core/   kdf(Argon2id)、settings、theme_runtime、lock_runtime、window_secure、lan_node
  data/   database(开库/换密钥)、schema、repos、backup_store、lan_transfer、
          notebook_transfer、photo_spot_store、device_key_store、photo_janitor
  ui/     screens/(home, note_list, envelope_editor, search, settings,
          vault_gate, vault_home, change_vault_pin, lan_transfer)、unlock、bootstrap
test/
  data/   库、仓库、加密、备份、传输
  ui/     各屏交互、横竖屏、golden 截图
```

## 构建

```powershell
$env:Path='D:\APP\flutter\bin;D:\APP\Java\jdk-17.0.21\bin;'+$env:Path
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:JAVA_HOME='D:\APP\Java\jdk-17.0.21'
$env:ANDROID_HOME='D:\APP\Android'
powershell -ExecutionPolicy Bypass -File 'scripts\build_apk.ps1' -Mode release
```

产物：`build\app\outputs\flutter-apk\app-release.apk`（约 55 MB）。

### 两个必须知道的构建坑

1. `pubspec.yaml` 末尾的 `hooks: user_defines: sqlite3` 段是 sqlite3 原生库的镜像配置，**不能删改** —— 直连 GitHub 会超时。
2. pub cache 里 `jni-1.1.2/src/CMakeLists.txt` 打过一个 `[ENVX-PATCH]` 补丁（给 `third_party/global_jni_env.c` 加 `-O0`），是 clang19 + NDK28.2 静默失败的真解法；清缓存重下会丢，丢了要重新打。

## 测试

**不要跑全量 `flutter test`**：flutter_tools 清理临时目录时会报 `errno 145` 并打断。逐文件跑：

```powershell
flutter test test\ui\editor_page_test.dart --concurrency=1 --timeout=180s
```

golden 重出：

```powershell
$env:ENVX_SHOTS='1'
flutter test test\ui\screenshots_test.dart --update-goldens --concurrency=1 --timeout=180s
```

`test\ui\goldens\` 是基线；`test\data\kdf_benchmark_test.dart` 是 Argon2 压测，耗时数分钟，按需手动跑。

## 已知限制

- **Android 签名**：release 仍用 debug keystore（能覆盖升级，不能上架）。换正式签名会导致已装用户必须卸载重装、数据丢失。
- **iOS**：需要云 Mac + 证书，当前未构建。
- **golden 里的插图**：headless 环境 `Image.file` 异步解码不完成，截图用例改用预解码注入（`decodedPhotos` 参数）。
- **图文混排**：「四周型」（文字绕图排成凹字形）做不了，`TextField` 不支持按图轮廓回流；要多这一档得换富文本编辑器。
- **云备份 / 生物识别**：没有后端与 `local_auth`，设置页已把这两项下架，不做假开关。
