import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名：android/key.properties（已加入 .gitignore，不会随仓库公开）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 车机版识别：与 Dart 侧 `bool.fromEnvironment('ABTS_CAR')` 同源。
// `flutter build apk --dart-define=ABTS_CAR=true` 会把 dart-define 以 base64 列表
// 形式传进 gradle 的 `dart-defines` 属性，这里解出来判断，保证 Gradle 与 Dart 判断一致。
//
// ⚠️ 必须用 `=true` 而不是 `=1`：Dart 的 bool.fromEnvironment 只把字符串 "true"
// 视为真，`=1` 在 Dart 侧是 false，会导致 Gradle 判成车机版而 Dart 判成手机版。
// 这里额外兼容 "1"，避免用户按直觉写错时 Gradle 与 Dart 判断不一致
// （Gradle 侧多认不会造成危害，但两边必须同源，故以 "true" 为准）。
val isCarBuild: Boolean = run {
    val raw = (project.findProperty("dart-defines") as String?) ?: ""
    raw.split(',')
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching { String(Base64.getDecoder().decode(encoded.trim())) }.getOrNull()
        }
        .any { it.trim() == "ABTS_CAR=true" }
}

android {
    namespace = "dev.pages.abts"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 车机版使用独立包名，可与手机版并存安装、互不覆盖
        applicationId = if (isCarBuild) "dev.pages.abts.car" else "dev.pages.abts"
        // 应用列表中单独标识，避免两个版本混淆
        manifestPlaceholders["appLabel"] =
            if (isCarBuild) "阿B听书车机版" else "阿B听书"
        // 车机默认锁定横屏；手机版交由 Dart 按用户设置动态切换
        manifestPlaceholders["carOrientation"] =
            if (isCarBuild) "landscape" else "unspecified"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 时用正式证书签名，否则回退 debug 签名（便于他人构建）
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
