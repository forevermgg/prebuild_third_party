plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.forever.base"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        ndkVersion = "29.0.14206865"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
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
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
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
    implementation(project(":deps"))
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
    //noinspection GradleDynamicVersion
    // implementation("com.facebook.soloader:soloader:0.13.0+")
}