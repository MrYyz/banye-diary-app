# 信封日记 · 一键打包 apk
#
# 为什么要在 D:\APP\envx_build 里构建，而不是直接在工程目录：
#   工程目录含中文（信封日记App），AGP 的 CMake 任务在中文路径下不会生成 build.ninja，
#   报 "Expected output file ... libdartjni.so but there was none"。加
#   android.overridePathCheck=true 只放过了 AGP 自己的路径检查，管不到 CMake/ninja。
#   所以把源码同步到纯英文路径构建，再把 apk 拷回来。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Mode release

param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'debug'
)

$ErrorActed = $false
$Src = Split-Path -Parent $PSScriptRoot          # 工程根
$Dst = 'D:\APP\envx_build'                        # 纯英文构建目录
$Flutter = 'D:\APP\flutter\bin'
$Jdk = 'D:\APP\Java\jdk-17.0.21'

# --- 环境 ---
$env:Path = "$Flutter;$Jdk\bin;$env:Path"
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:JAVA_HOME = $Jdk
$env:ANDROID_HOME = 'D:\APP\Android'
$env:ANDROID_SDK_ROOT = 'D:\APP\Android'
$env:SDK_TEST_BASE_URL = 'https://mirrors.cloud.tencent.com/AndroidSDK/'

Write-Host "[1/4] 同步源码到 $Dst"
& cmd /c "robocopy `"$Src`" `"$Dst`" /E /XD build .dart_tool .git artifacts /NFL /NDL /NJH /NJS /NP" | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Error "robocopy 失败，退出码 $LASTEXITCODE"; exit 1 }

Write-Host "[2/4] pub get"
Push-Location $Dst
try {
    & flutter.bat pub get
    if ($LASTEXITCODE -ne 0) { Write-Error "pub get 失败"; exit 1 }

    Write-Host "[3/4] 构建 apk（$Mode）"
    & flutter.bat build apk "--$Mode"
    if ($LASTEXITCODE -ne 0) { Write-Error "构建失败，日志见 $Dst\build_$Mode.log"; exit 1 }
}
finally {
    Pop-Location
}

Write-Host "[4/4] 拷回原工程"
$built = Get-ChildItem -LiteralPath "$Dst\build\app\outputs\flutter-apk" -Filter '*.apk' |
    Where-Object { $_.Name -notlike '*.sha1' } | Select-Object -First 1
if (-not $built) { Write-Error "没有找到 apk 产物"; exit 1 }

$outDir = Join-Path $Src 'build\app\outputs\flutter-apk'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Copy-Item -LiteralPath $built.FullName -Destination (Join-Path $outDir $built.Name) -Force

$final = Join-Path $outDir $built.Name
Write-Host ("完成: {0}  {1:N2} MB" -f $final, ((Get-Item -LiteralPath $final).Length / 1MB))
Write-Host "装到手机: adb install -r `"$final`""
