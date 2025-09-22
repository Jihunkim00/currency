########################################
# 공통: 어노테이션/제네릭 보존 (리플렉션/JSON용)
########################################
-keepattributes Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

########################################
# ML Kit / Google Play Services / CameraX
########################################
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.camera.** { *; }

# (옵션) Play Services가 끌고오는 경고 무시
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**

########################################
# Gson / JSON (엔티티가 리플렉션으로 직렬화/역직렬화될 때)
########################################
-keep class com.google.gson.** { *; }

# ⚠️ 여기를 "실제 패키지 경로"로 바꾸세요!
# 예: appId가 com.example.currency 이고 domain/entities.dart가
#   lib/domain/entities.dart 에 있다면:
#   -keep class com.example.currency.domain.** { *; }
-keep class com.example.currency.domain.** { *; }


########################################
# 네트워크 스택 (Retrofit/OkHttp 쓰는 경우만)
########################################
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

########################################
# Kotlin / Coroutines (경고 정리)
########################################
-dontwarn kotlinx.coroutines.**
