allprojects {
    repositories {
        // Flutter 引擎产物（io.flutter:*_debug）只存在于 Flutter 自己的下载仓库，
        // dl.google.com 上没有对应坐标，缺了这一条解析会一路撞到 dl.google.com 超时。
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        // 国内镜像优先，理由同 settings.gradle.kts
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// release 包会给每个插件子工程跑 lintVital 分析，而 AGP 9.x 的 lint 在
// image_picker_android 的 ExifDataCopier.java 上会崩（CommentDetector 抛
// NoSuchMethodError: JavaDocParser.parseDataItem）——这是 lint 自身的 bug，与代码无关。
// 关掉它不影响 apk 产物，只是不做 release 期的 lint 卡口；静态检查仍靠 flutter analyze。
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
