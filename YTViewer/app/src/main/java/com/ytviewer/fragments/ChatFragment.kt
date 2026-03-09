package com.ytviewer.fragments

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.ytviewer.R
import com.ytviewer.utils.YouTubeUrlParser

class ChatFragment : Fragment() {

    private lateinit var webView: WebView
    private lateinit var tvLiveOnly: TextView
    private var videoId: String? = null
    private var isLive: Boolean = false

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_chat, container, false)
        webView = view.findViewById(R.id.webViewChat)
        tvLiveOnly = view.findViewById(R.id.tvLiveOnly)
        setupWebView()
        return view
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            loadWithOverviewMode = true
            useWideViewPort = true
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            userAgentString = "Mozilla/5.0 (Linux; Android 11; Pixel 5) " +
                    "AppleWebKit/537.36 (KHTML, like Gecko) " +
                    "Chrome/90.0.4430.91 Mobile Safari/537.36"
        }
        webView.webViewClient = WebViewClient()
        webView.webChromeClient = WebChromeClient()
    }

    fun setVideoId(id: String, live: Boolean) {
        videoId = id
        isLive = live
        refreshView()
    }

    private fun refreshView() {
        val id = videoId ?: return
        if (isLive) {
            tvLiveOnly.visibility = View.GONE
            webView.visibility = View.VISIBLE
            val chatUrl = YouTubeUrlParser.getLiveChatEmbedUrl(id)
            webView.loadUrl(chatUrl)
        } else {
            // For VOD, attempt to show community chat / replay chat
            val replayChatUrl = "https://www.youtube.com/live_chat_replay?v=$id&is_popout=1"
            webView.loadUrl(replayChatUrl)
            webView.visibility = View.VISIBLE
            tvLiveOnly.visibility = View.GONE
        }
    }

    override fun onDestroyView() {
        webView.destroy()
        super.onDestroyView()
    }
}
