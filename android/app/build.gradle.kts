// android/app/build.gradle.kts
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // Flutter Gradle Plugin은 Android/Kotlin 플러그인 뒤에
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    // 루트에 key.properties가 있을 때만 로드
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
    // key.properties 예시 (git에 올리지 마세요):
    // storePassword=your-keystore-password
    // keyPassword=your-key-password
    // keyAlias=upload
    // storeFile=C:/Users/jihun/keystores/upload-keystore.jks   // Windows는 슬래시(/) 권장
}

android {
    namespace = "com.thj.currency"

    // Flutter 플러그인이 제공하는 버전 사용
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // NDK 경고 해결

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.thj.currency"
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 릴리스 서명 키 로드 (없으면 null로 두어 로컬 디버그 빌드 가능)
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile") ?: ""
            if (storeFilePath.isNotBlank()) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            // 디버그는 기본 디버그 키로 서명
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // ✅ 배포는 반드시 release 키로 서명
            signingConfig = signingConfigs.getByName("release")

            // 난독화/리소스축소 활성화
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // (선택) 패키징 경고/중복 리소스 정리
    packaging {
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ❌ ML Kit BOM 제거
    // implementation(platform("com.google.mlkit:mlkit-bom:31.0.0"))

    // ✅ 필요한 텍스트 인식 패키지만 명시 버전으로 추가
    implementation("com.google.mlkit:text-recognition:16.0.1")          // Latin
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")  // Chinese
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")   // Korean
}
