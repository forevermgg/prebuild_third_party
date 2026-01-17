package com.forever.base

object BaseNativeLibLoader {
    external fun baseVersionInfo(): String
    init {
        System.loadLibrary("forever")
    }
}