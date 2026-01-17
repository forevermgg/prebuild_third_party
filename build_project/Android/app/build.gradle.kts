plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

apply(from = "zstd.gradle")

apply(from = "ssl.gradle")

apply(from = "fmt.gradle")

apply(from = "uv.gradle")

apply(from = "cares.gradle")

android {
    namespace = "com.forever.app"
    compileSdk = 36

    defaultConfig {
        ndkVersion = "29.0.14206865"
        applicationId = "com.forever.app"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        externalNativeBuild {
            cmake {
                // 1. Add CMake arguments safely
                arguments.add("-DANDROID_WEAK_API_DEFS=ON")  // Enable weak symbol resolution [1,5](@ref)
                arguments.add("-DANDROID_STL=c++_shared")     // Use shared STL
                arguments.add("-DCMAKE_CXX_STANDARD=20")
                arguments.add("-DCMAKE_CXX_EXTENSIONS=OFF")
                arguments.add("-DANDROID_NDK_HOME=${android.ndkDirectory.absolutePath}")
                // 2. Set C++ flags
                cppFlags += "-std=c++20"
                //cppFlags += "-fexceptions"
            }
        }
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    val projectRootPath = project.rootDir
    println("projectRootPath: $projectRootPath")
    val projectRootCMakeListsPath = project.rootDir.path + "/../../CMakeLists.txt"
    println("projectRootCMakeListsPath: $projectRootCMakeListsPath")
    externalNativeBuild {
        cmake {
            path(projectRootCMakeListsPath)
            // version = "4.1.2"
            version = "3.30.3"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21  // Java 21
        targetCompatibility = JavaVersion.VERSION_21
    }
    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
    }
    kotlin {
        jvmToolchain(21)
    }
    buildFeatures {
        viewBinding = true
        buildConfig = true
        aidl = true
    }
    buildTypes {
        getByName("release") {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
        getByName("debug") {
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }
    buildFeatures.prefab = true
}

dependencies {
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.lifecycle.livedata.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.navigation.fragment.ktx)
    implementation(libs.androidx.navigation.ui.ktx)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    implementation(libs.timber)
    implementation(libs.process.phoenix)
    implementation(libs.bson)
    implementation(libs.once)
}

// 2. 关联 CMake Task
afterEvaluate {
    // 匹配所有 cmake*Build Task
    tasks.filter { it.name.startsWith("configureCMake") && it.name.endsWith("buildCMake") }
        .forEach { it.dependsOn("preBuild") }
}