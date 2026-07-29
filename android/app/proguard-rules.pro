# R8 / ProGuard rules for the release build.
#
# Referenced from `build.gradle.kts`'s release `proguardFiles(...)` alongside
# AGP's `proguard-android-optimize.txt`. Consumed only when `isMinifyEnabled`
# is true.
#
# Scope note: this app persists counters, histories and settings by
# hand-rolling `kotlinx.serialization`'s JSON *tree* API — `Json.parseToJsonElement`
# plus explicit `fromJson`/`toJson` functions on each model type (see
# `model/CounterModel.kt`, `model/Counter.kt`, `model/CounterHistory.kt`). There
# are no `@Serializable` classes and no generated `$$serializer` companions, so
# the usual "keep every serializer" rule set does not apply. What still has to
# survive is the serialization *runtime* itself, which R8 reaches reflectively.

# --- kotlinx.serialization runtime -------------------------------------------
# The JSON tree API resolves built-in serializers through `SerializersKt` and the
# `kotlinx.serialization.json` internals. Keep the runtime's own entry points;
# without these, `parseToJsonElement` can fail at runtime on a minified build
# with a NoSuchMethodError that no JVM unit test reproduces.
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-dontwarn kotlinx.serialization.**

# --- App model types ----------------------------------------------------------
# The model classes are read back from SharedPreferences at launch. Their own
# parsing is explicit (no reflection), so R8 may freely rename them — but keeping
# them makes a persistence regression legible in a stack trace instead of
# surfacing as silently-reset counters. Cheap: a handful of small data classes.
-keep class com.codeyam.android.model.** { *; }

# --- Compose ------------------------------------------------------------------
# The Compose compiler plugin emits synthetic classes AGP's default rules already
# cover; this only silences warnings from optional desktop/tooling artifacts that
# are absent on Android.
-dontwarn androidx.compose.**

# --- Diagnostics --------------------------------------------------------------
# Keep line numbers so a release-build crash report maps back to source. The
# source file name itself is renamed to hide the original path.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
