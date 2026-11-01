plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "com.dzafirov.tvskin"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.dzafirov.tvskin"
        minSdk = 31
        targetSdk = 34
        versionCode = 1
        versionName = "0.1"
        // TMDB key for the Netflix/HBO strip, from the repo's .env (never committed). Empty → the strip shows banners.
        val tmdbKey = rootProject.file("../.env").takeIf { it.exists() }?.readLines()
            ?.firstOrNull { it.trim().startsWith("TMDB_API_KEY=") }?.substringAfter("=")?.trim()?.trim('"').orEmpty()
        buildConfigField("String", "TMDB_API_KEY", "\"$tmdbKey\"")
    }

    buildTypes {
        release {
            // Optimised build for the TV: R8 shrinks and optimises Compose; signed with the debug key (side-loaded).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.tv.material)
    implementation(libs.coroutines.android)
    implementation(libs.androidx.profileinstaller)

    testImplementation(libs.junit)
    testImplementation(libs.androidx.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.json)
    debugImplementation(libs.compose.ui.test.manifest)
}
