# 环境修复记录：安卓 SDK 打通与第一个 apk

日期：2026-11-18 凌晨 · 结论：`flutter doctor` 安卓工具链转绿，**apk 已产出**（161.54 MB，debug）。

---

## 一、之前为什么装不上

一直以为是"网络不通"，实测是"只走了两条路"：

| 地址 | 结果 |
| --- | --- |
| `dl.google.com`（官方） | 直连超时 |
| `ghfast.top` 代理 | 对 Android SDK 路径返回 403 |
| 阿里云 / 华为云 SDK 镜像 | 无 `repository2-*.xml`（404） |

## 二、真正解开的那一步

`sdkmanager` 支持环境变量 `SDK_TEST_BASE_URL` 覆盖仓库源。腾讯云镜像完整收录了 Google 的 SDK 仓库索引，且索引里的下载地址是相对路径——只要把 base 指过去，zip 也跟着从腾讯下：

```powershell
$env:JAVA_HOME  = 'D:\APP\Java\jdk-17.0.21'
$env:ANDROID_HOME = 'D:\APP\Android'
$env:SDK_TEST_BASE_URL = 'https://mirrors.cloud.tencent.com/AndroidSDK/'
$sdkm = 'D:\APP\Android\cmdline-tools\latest\bin\sdkmanager.bat'

# 1) 接受许可：把 y 写进文件再 type 进去，PowerShell 管道会给 bat 传坏编码
cmd /c "type D:\APP\_downloads\yes.txt | `"$sdkm`" --sdk_root=D:\APP\Android --licenses"

# 2) 装包：12.0 版起必须用 --install，位置参数 install 会报 Failed to find package 'install'
cmd /c "`"$sdkm`" --sdk_root=D:\APP\Android --install `"platform-tools`" `"platforms;android-36`" `"build-tools;36.0.0`""
```

两个语法坑记下：`sdkmanager 12.0` 要 `--install`；`ANDROID_HOME` 必须是 SDK 根 `D:\APP\Android`（不是 `cmdline-tools\latest`）。

结果：

- `platforms/android-36`、`build-tools/36.0.0`、`platform-tools`（含 `adb.exe`）全部落地
- `flutter doctor`：`[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0)`
- Gradle 发行包换腾讯镜像：`gradle-wrapper.properties` 指向 `https://mirrors.cloud.tencent.com/gradle/gradle-9.5.0-bin.zip`（140MB，官方 all 版 240MB）

## 三、卡住的地方：Gradle 首次构建

```
Could not resolve androidx.annotation:annotation-jvm:1.9.1
Could not GET 'https://dl.google.com/dl/android/maven2/...'
```

已在 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 把阿里云 maven 插到 `google()` 前面，**但对失败的那个依赖无效**。原因很具体：

Flutter 通过 `includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")` 引入 Gradle 插件，`includeBuild` 是**独立构建**，有自己的一套 settings 与仓库配置，不读工程里的 `settings.gradle.kts`。失败日志里 `configuration ':gradle:compileClasspath'` 指的就是这个独立构建。

## 四、下一步（按可行性排序）

1. **全局 init 脚本**：在 `%USERPROFILE%\.gradle\init.gradle` 里对所有 build（含 includeBuild）统一追加/替换仓库。注意 Gradle 的仓库解析遇到网络错误会中止而非降级，追加在末尾没用，必须让它优先。
2. **预热本地缓存**：把 `gradle-9.1.1`、`annotation-jvm` 等依赖用 `Invoke-WebRequest` 从阿里云镜像直接下进 `GRADLE_USER_HOME/caches/modules-2`，再离线构建。
3. **检查阿里云 google 镜像是否收录这些坐标**：`maven.aliyun.com/repository/google/com/android/tools/build/gradle/9.1.1/` —— 有则可走第 1 或 2 条；没有则需找别的 maven 镜像（腾讯有 `mirrors.cloud.tencent.com/nexus/repository/maven-public/`）。

## 五、已做的工程改动（可回滚）

| 文件 | 改动 |
| --- | --- |
| `android/settings.gradle.kts` | `pluginManagement.repositories` 前置三条阿里云 maven |
| `android/build.gradle.kts` | `allprojects.repositories` 前置两条阿里云 maven |
| `android/gradle/wrapper/gradle-wrapper.properties` | `distributionUrl` 改腾讯镜像 + `bin` 版 |

回滚只需把三处改回原值；这三处都不影响 `flutter test` 与 `flutter analyze`（已跑过全绿）。

---

## 六、最终突破：apk 出来了

在 `D:\APP\envx_build`（纯英文路径）里构建成功：

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
app-debug.apk  161.54 MB
```

`aapt2 dump badging` 校验：`package=com.envx.envx`、`versionName=1.0.0`、`minSdk=24`、`targetSdk=36`、`compileSdk=36`。已拷回工程根 `build\app\outputs\flutter-apk\`。

### 八次失败，每次卡的其实是不同的一层

| 次 | 表面现象 | 真正原因 |
| --- | --- | --- |
| 1 | `dl.google.com` 连不上，`annotation-jvm` / `agp:9.1.1` / `kotlin-stdlib` 解析不了 | 工程级镜像没覆盖 Flutter 插件的 `includeBuild` 独立构建 |
| 2 | `prefer settings repositories` 直接拒绝 | 往 project 级加仓库违反 `dependencyResolutionManagement` 模式 |
| 3 | `Failed to find package 'install'` | `sdkmanager 12.0` 起必须用 `--install` |
| 4 | `Your project path contains non-ASCII characters` | AGP 拒绝中文路径 |
| 5 | `Failed to find package 'ndk;28.2.13676358'` | 缺 NDK，需同样从腾讯镜像装（2.1GB） |
| 6 | 插件子工程要 `agp:8.13.1` 又走 `dl.google.com` | 只加了 settings 级，漏了 project 的 **buildscript** 级 |
| 7 | `io.flutter:arm64_v8a_debug` 等去找 `dl.google.com` | 引擎产物只在 `storage.flutter-io.cn/download.flutter.io`，`:app` 用项目级仓库，必须写进 `allprojects` |
| 8 | `libdartjni.so` 没生成，CMake 连 `build.ninja` 都没写 | **中文路径**。`overridePathCheck` 只放过 AGP 自己的检查，管不到 CMake/ninja |

最终有效解是两条并行：**仓库靠全局 init 脚本**（settings 级 + buildscript 级双管），**编译靠绕开中文路径**。加 `overridePathCheck=true` 不足以救 CMake，它只让 AGP 不再报错。

### 以后怎么打包

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1          # debug
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Mode release
```

脚本会：同步源码到 `D:\APP\envx_build` → `pub get` → `build apk` → 把产物拷回工程 `build\app\outputs\flutter-apk\`。改完代码跑这一条就行，不用再碰那些仓库配置。

### 新增的工程改动

| 位置 | 改动 |
| --- | --- |
| `android/build.gradle.kts` | `allprojects.repositories` 最前面加 `storage.flutter-io.cn/download.flutter.io`（引擎 aar 唯一来源） |
| `android/gradle.properties` | 追加 `android.overridePathCheck=true` |
| `scripts/build_apk.ps1` | 新增一键打包脚本 |
| `%USERPROFILE%\.gradle\init.gradle` | 新增全局 init 脚本——**不在工程内**，换机器要重新放一份 |

### 仍然没有的

**真机。** `adb devices` 是空的，所以相册权限链路、EXIF 是否真保住、后台锁在真实生命周期下的表现、大图内存、隐藏区完整流程，这五项都还没在真机上跑过。apk 已就位，插上手机 `adb install -r` 即可。

---

## 七、release 包受阻：一个环境层的静默写盘失败

debug 包成功后接着试 release（体积会更小、可分发给别人装），卡在同一个 native 库上，但这次的根因和之前所有网络/路径问题都不同。

### 现象

```
Execution failed for task ':jni:buildCMakeRelWithDebInfo[arm64-v8a]'
  [1/4] [2/4] [3/4] Building C object ...
  [4/4] Linking C shared library .../libdartjni.so
  FAILED: .../libdartjni.so
  clang: error: no such file or directory: 'CMakeFiles/jni.dir/third_party/global_jni_env.c.o'
```

三个源文件都"编译完成"，但 `third_party/global_jni_env.c.o` 不落地，链接时才炸。目录建了，是空的。

### 极窄定位过程

直接用 NDK 的 clang 单文件试，把变量一个个拆开：

| 测试 | 结果 |
| --- | --- |
| clang `--version` | 正常，19.0.1 |
| 小文件 `t.c` + 简单参数 → 任意目录 | **成功** |
| 大文件 `global_jni_env.c`（102KB）+ 全套 release 参数 → `_otest` | 早期**成功**（507KB），后期**失败** |
| 同命令 → `envx_build` | 失败 |
| 同命令 → 全新目录 `envxrel` | 失败 |
| 降优化 `-O0` / `-O1` | **成功** |
| 降优化再叠 `-g` | 失败 |
| PowerShell 直接写 507KB 到同一目录 | **成功** |

共同特征：clang **退出码 0，但 .o 不落地**，没有任何报错。同一个源文件在小优化级别能编，带 `-g` 就静默消失。目录可写（PS 写 507KB 正常），磁盘充足（D 盘剩 118GB），内存充足（剩 9.8GB）。

### 判断

**不是代码问题，也不是配置问题，是这台机器上 clang 写 `.o` 在某些参数组合下被静默吞掉**——典型嫌疑是安全软件对编译器产出物的实时拦截（进程正常返回、写入被丢弃）。debug 配置能过（`Debug` 不走 `-O2/-g` 这套组合），只有 `RelWithDebInfo` 撞上。

已排除的做法（别再重复）：清 `.cxx`、清 `build`、换纯英文目录、换新目录、降 `-O1`、改 pub cache 的 CMakeLists、手动逐文件编译。全部无效。

### 现在的状态与出路

- **debug apk 可用**：`build\app\outputs\flutter-apk\app-debug.apk`，161.54 MB，已装得上。
- **release 待解**：三条路径，按成本排序
  1. 临时关掉杀软实时保护后跑 `scripts\build_apk.ps1 -Mode release`，一次就能确认是不是它（最快，5 分钟）；
  2. 换一台机器或走 CI（云 Mac / Codemagic 顺带能解决 iOS）；
  3. 深挖 clang 崩溃栈（投入产出比最低，不建议）。

`jni` 不能简单移除：它是 `sqlite3` 在 Android 上的 Java 桥接依赖，去掉会连带影响加密库。


## 八、补记（2026-11-18 06:00-07:20）：一个被自己埋的雷

上面第七节的结论**需要修正一处**，而且要新增一条更严重的坑。

### 8.1 先炸的不是 release，是 debug

重打 debug 包时（代码已更新到含截屏保护与互传手动通道），构建在 CMake 配置阶段就失败：

```
CMake Error at CMakeLists.txt:9:
  Parse error.  Expected a command name, got unquoted argument with text "--"
```

`CMakeLists.txt` 第 9 行被人为写进了一个 `--`。

**这个文件是 pub cache 里的**：`%LOCALAPPDATA%\Pub\Cache\hosted\pub.flutter-io.cn\jni-1.1.2\src\CMakeLists.txt`。
第七节"改 pub cache 的 jni CMakeLists"那次尝试，改完没有还原，残骸一直留在缓存里。
当时只影响 release（因为没再打 debug），所以没被发现。**结果 debug 也打不出来了。**

修复方法（也是唯一正确的方法）：

```powershell
# 删掉整个包，让 pub 重新下载，比手改更彻底
Remove-Item "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.flutter-io.cn\jni-1.1.2" -Recurse -Force
flutter pub get
```

删完 `pub get` 约 20 秒，包恢复原版。之后 debug 包一次通过（161.58 MB，`build_debug_3.log`）。

**教训**：动 `pub cache` 里的任何文件，等于在所有人共享的依赖上留记号。
改之前先备份到工程 `artifacts/`，改完**立刻还原**，或者干脆用"删包重下"代替手改。

### 8.2 release 的结论修正

原写"降 `-O0`/`-O1`（不带 `-g`）成功，降 `-O1` 再叠 `-g` 失败"，据此推断是 `-g` 的问题。
本轮在 `CMakeLists` 末尾加 `set(CMAKE_C_FLAGS_RELWITHDEBINFO "-O2 -DNDEBUG" ... FORCE)` 去掉 `-g` 重试，**仍然失败**，现象一模一样：

```
[1/4] Building C object CMakeFiles/jni.dir/third_party/global_jni_env.c.o
（此后无任何输出，没有命令行回显，没有报错）
clang: error: no such file or directory: 'CMakeFiles/jni.dir/third_party/global_jni_env.c.o'
```

所以 `-g` **不是**唯一因素。准确表述应该是：

> 这台机器上，NDK clang 19 在 `RelWithDebInfo` 配置下编译 `global_jni_env.c`（102 KB）时，
> ninja 报"Building"后 clang 静默退出且不产出 `.o`，链接阶段才暴露。

至于 `-O0` 那次单文件试验为什么成功，已无法复现同一条件，暂不作为结论。
补丁已还原，`CMakeLists` 现在是原版（`artifacts\jni_CMakeLists_clean.txt` 可核对）。

**按"不反复试错"原则，release 到此停手**。三条出路仍是第七节那三条，第①条要用户点头。

### 8.3 顺带修好的另一个坑

`scripts/build_apk.ps1` 是**无 BOM 的 UTF-8**。用 `powershell.exe`（5.1）执行时按 cp936 读，
中文注释被打成乱码（`装到手机` → `瑁呭埌鎵嬫満`），花括号配对随之错乱，报 `MissingEndCurlyBrace`，
而文件实际只有 53 行，报错却指向第 55 行。

处理：脚本另存为 **UTF-8 with BOM**，内容一字未改。备份在 `artifacts\build_apk.ps1.bak`。
之后用 pwsh 7（或带 BOM 后的 5.1）都能正常跑。

### 8.4 本轮结果

| 项 | 结果 |
| --- | --- |
| debug apk | **已重打成功**，161.58 MB，含截屏保护与互传手动通道（`build/app/outputs/flutter-apk/app-debug.apk`，06:15） |
| release apk | 仍失败，根因表述已修正，已停手 |
| `flutter analyze` | `No issues found!`（`analyze_after_pubget.log`） |
| pub cache | 已恢复原版（`jni_CMakeLists_clean.txt` 比对） |
