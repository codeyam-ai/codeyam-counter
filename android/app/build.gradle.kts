import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// Release signing. Reads the upload key from android/keystore.properties
// (git-ignored) or, as a fallback, the ANDROID_KEYSTORE_* env vars (used by CI).
// When neither is present the release build is left UNSIGNED instead of failing,
// so contributors and keyless CI can still run `bundleRelease`; only a machine
// with the upload key produces a Play-uploadable AAB.
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) FileInputStream(keystorePropsFile).use { load(it) }
}
fun signingProp(prop: String, env: String): String? =
    keystoreProps.getProperty(prop) ?: System.getenv(env)
val releaseStoreFile = signingProp("storeFile", "ANDROID_KEYSTORE_FILE")
val hasReleaseSigning = releaseStoreFile != null

android {
    namespace = "com.codeyam.android"
    compileSdk = 35

    defaultConfig {
        // The Play Store identity, permanent once published — deliberately the
        // same reverse-DNS name as the iOS bundle ID (`com.codeyam.counter`) so
        // both stores show one app. The Kotlin `namespace` above is still the
        // scaffold's `com.codeyam.android`; the two need not match, and moving
        // the namespace would rewrite every source path in .codeyam's test
        // registry and dependency graph for no user-visible gain.
        applicationId = "com.codeyam.counter"
        minSdk = 24
        // Play requires new uploads to target API 35 (Android 15) on all tracks.
        targetSdk = 35
        // Defaults to 1 for a local/manual build. CI passes
        // -PversionCodeOverride=<n> (a large, monotonic value) so every
        // automated Play upload gets a unique, increasing versionCode — Play
        // rejects a track upload that reuses an existing versionCode.
        versionCode = (project.findProperty("versionCodeOverride") as String?)?.toIntOrNull() ?: 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    signingConfigs {
        // Only define the release config when the upload key is actually present,
        // so a keyless build doesn't fail on missing store/password values.
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = signingProp("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingProp("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingProp("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // R8 shrinks + obfuscates the release artifact. Safe here because
            // persistence is explicit JSON-tree parsing, not `@Serializable`
            // reflection — see the scope note in `proguard-rules.pro`.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Sign the release AAB/APK with the upload key when available;
            // otherwise it builds unsigned (not uploadable, but inspectable).
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
    buildFeatures {
        compose = true
        // Generates BuildConfig.VERSION_NAME / VERSION_CODE so the app can show
        // its own version (see the footer in AppSettingsPanel).
        buildConfig = true
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    testOptions {
        unitTests {
            // Robolectric needs merged Android resources to inflate the Compose
            // test activity and resolve theme/resource references.
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit)
    // Compose UI tests that run under plain `testDebugUnitTest` via Robolectric
    // (no emulator — matches ci.yml's ubuntu android job). The BOM must be on the
    // test config too so the versionless test artifacts resolve.
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.compose.ui.test.junit4)

    debugImplementation(libs.androidx.compose.ui.tooling)
    // The test manifest must be on the debug VARIANT, not a test config: it is an
    // AAR whose only job is contributing `ComponentActivity` to the merged
    // application manifest (manifest merging is a per-variant build concern, and
    // Robolectric reads the variant's merged manifest). It must never reach the
    // release artifact, so it stays debug-only — which is exactly why the Compose
    // interaction tests that need it live in `src/testDebug/`, not `src/test/`.
    // Putting them in the variant-agnostic `src/test/` made `testReleaseUnitTest`
    // run a test whose host activity structurally cannot exist on that variant.
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
