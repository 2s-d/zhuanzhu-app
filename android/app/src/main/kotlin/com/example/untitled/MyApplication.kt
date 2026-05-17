package com.example.untitled

import android.app.Application
import com.mobile.auth.gatewayauth.PhoneNumberAuthHelper
import com.mobile.auth.gatewayauth.TokenResultListener

/**
 * 初始化阿里云号码认证 SDK 的 Application
 * （学习项目，先简单初始化，后续在 Flutter 侧通过 MethodChannel 调用获取 token）
 */
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // 初始化号码认证 SDK
        val authHelper = PhoneNumberAuthHelper.getInstance(
            applicationContext,
            object : TokenResultListener {
                override fun onTokenSuccess(ret: String?) {
                    // 这里只做初始化，不处理回调逻辑
                }

                override fun onTokenFailed(ret: String?) {
                    // 同上，后续真正获取 token 时会重新设置监听
                }
            }
        )

        // 打开 SDK 内部日志，便于调试
        authHelper.reporter.setLoggerEnable(true)
        // 把 BuildConfig 里的 AUTH_SECRET 传给 SDK
        authHelper.setAuthSDKInfo(BuildConfig.AUTH_SECRET)
    }
}

