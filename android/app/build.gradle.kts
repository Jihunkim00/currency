dependencies {
    // ❌ 삭제: implementation(platform("com.google.mlkit:mlkit-bom:31.0.0"))

    // ✅ 명시 버전으로 추가 (필요한 것만 남기세요)
    implementation("com.google.mlkit:text-recognition:16.0.1")          // Latin
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")  // Chinese
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")   // Korean
}



plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.currency"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // 앞서 경고 해결용

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.currency"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // 디버그는 난독화/리소스축소 끔 (기본값이지만 명시해두면 안전)
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // 임시로 디버그 키로 서명 중이면 이 줄 유지, 배포 전엔 release 키로 교체
            signingConfig = signingConfigs.getByName("debug")

            // ✅ R8/ProGuard 켜고 규칙 파일 적용
            isMinifyEnabled = true
            isShrinkResources = true

            // 기본 최적화 규칙 + 프로젝트 규칙
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


