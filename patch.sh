#!/bin/bash
set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"
APP="$REPO_ROOT/YTViewer/app/src/main"
echo "📁 Repo: $REPO_ROOT"
cat > "$APP/java/com/ytviewer/MainActivity.kt" << 'KTEOF'
package com.ytviewer

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Rational
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.core.view.updatePadding
import com.google.android.material.tabs.TabLayout
import com.ytviewer.databinding.ActivityMainBinding
import com.ytviewer.fragments.ChatFragment
import com.ytviewer.fragments.CommentsFragment
import com.ytviewer.utils.YouTubeUrlParser

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private var currentVideoId: String? = null
    private var isDarkMode = true
    private var lastTouchTime = 0L
    private val touchWindowMs = 600L
    private var isVideoPaused = false

    private val commentsFragment = CommentsFragment()
    private val chatFragment = ChatFragment()

    private val ACTION_PLAY_PAUSE = "com.ytviewer.PIP_PLAY_PAUSE"
    private val REQUEST_PLAY_PAUSE = 1

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_PLAY_PAUSE) {
                togglePlayPause()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge so topBar doesn't overlap system status bar
        WindowCompat.setDecorFitsSystemWindows(window, false)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Apply status bar inset to topBar so it sits below the status bar
        ViewCompat.setOnApplyWindowInsetsListener(binding.topBar) { view, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            view.updatePadding(top = statusBar.top)
            insets
        }

        setupWebPlayer()
        setupUrlInput()
        setupThemeToggle()
        setupPipButton()
        setupTabs()
        setupFragments()
        handleIntent(intent)

        binding.root.post {
            val defaultUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            binding.urlInputField.setText(defaultUrl)
            loadVideo(defaultUrl)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, IntentFilter(ACTION_PLAY_PAUSE), RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(pipReceiver, IntentFilter(ACTION_PLAY_PAUSE))
        }
    }

    override fun onStop() {
        super.onStop()
        try { unregisterReceiver(pipReceiver) } catch (_: Exception) {}
    }

    private fun handleIntent(intent: Intent?) {
        val data: Uri? = intent?.data
        if (data != null) {
            val url = data.toString()
            binding.urlInputField.setText(url)
            loadVideo(url)
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "ClickableViewAccessibility")
    private fun setupWebPlayer() {
        binding.webPlayer.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            loadWithOverviewMode = true
            useWideViewPort = true
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            databaseEnabled = true
            cacheMode = WebSettings.LOAD_DEFAULT
            userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                    "AppleWebKit/537.36 (KHTML, like Gecko) " +
                    "Chrome/120.0.0.0 Safari/537.36"
        }

        binding.webPlayer.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE ->
                    lastTouchTime = SystemClock.elapsedRealtime()
            }
            false
        }

        binding.webPlayer.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) {
                request.grant(request.resources)
            }
        }

        binding.webPlayer.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                injectJs(view)
            }
        }
    }

    private fun injectJs(view: WebView?) {
        view?.evaluateJavascript("""
            (function() {
                var TOUCH_WINDOW = $touchWindowMs;

                // Override visibility API to prevent background pause
                Object.defineProperty(document, 'hidden', { get: function(){ return false; }, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: function(){ return 'visible'; }, configurable: true });
                document.addEventListener('visibilitychange', function(e){ e.stopImmediatePropagation(); }, true);

                // Track all clicks as potential user interaction
                document.addEventListener('click', function() {
                    window._lastTouch = Date.now();
                }, true);

                function patchVideo(video) {
                    if (video._patched) return;
                    video._patched = true;
                    video.addEventListener('pause', function() {
                        var timeSinceTouch = Date.now() - (window._lastTouch || 0);
                        if (timeSinceTouch > TOUCH_WINDOW) {
                            setTimeout(function(){ if(video.paused) video.play(); }, 80);
                        }
                    });
                }

                // MutationObserver to catch dynamically loaded video element
                var observer = new MutationObserver(function() {
                    var v = document.querySelector('video');
                    if (v) { patchVideo(v); }
                });
                observer.observe(document.body || document.documentElement, {
                    childList: true, subtree: true
                });

                var v = document.querySelector('video');
                if (v) patchVideo(v);
            })();
        """.trimIndent(), null)
    }

    private var pipVideoRatio = Rational(16, 9)

    private fun injectPipCss(view: WebView?, callback: (() -> Unit)? = null) {
        // Get video element bounds so we can set PiP aspect ratio correctly
        view?.evaluateJavascript("""
            (function() {
                var v = document.querySelector('video');
                if (v) {
                    var r = v.getBoundingClientRect();
                    return JSON.stringify({w: Math.round(r.width), h: Math.round(r.height), vw: v.videoWidth, vh: v.videoHeight});
                }
                return JSON.stringify({w:16, h:9, vw:16, vh:9});
            })();
        """.trimIndent()) { result ->
            try {
                val clean = result?.trim('"') ?: ""
                val json = org.json.JSONObject(clean)
                val vw = json.optInt("vw", 16).takeIf { it > 0 } ?: 16
                val vh = json.optInt("vh", 9).takeIf { it > 0 } ?: 9
                val gcd = gcd(vw, vh)
                pipVideoRatio = Rational(vw / gcd, vh / gcd)
            } catch (_: Exception) {
                pipVideoRatio = Rational(16, 9)
            }
            callback?.invoke()
        }
    }

    private fun gcd(a: Int, b: Int): Int = if (b == 0) a else gcd(b, a % b)

    private fun removePipCss(view: WebView?) {
        view?.evaluateJavascript("""
            (function() {
                var s = document.getElementById('pip-hide');
                if (s) s.remove();
            })();
        """.trimIndent(), null)
    }

    private fun togglePlayPause() {
        binding.webPlayer.evaluateJavascript("""
            (function() {
                window._lastTouch = Date.now();
                var v = document.querySelector('video');
                if (!v) return;
                if (v.paused) { v.play(); } else { v.pause(); }
            })();
        """.trimIndent(), null)
        isVideoPaused = !isVideoPaused
        // Update PiP action button icon
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setPictureInPictureParams(buildPipParams())
        }
    }

    private fun setupUrlInput() {
        binding.btnLoad.setOnClickListener {
            val url = binding.urlInputField.text.toString().trim()
            if (url.isNotEmpty()) loadVideo(url)
            else Toast.makeText(this, "請輸入 YouTube 網址", Toast.LENGTH_SHORT).show()
        }
        binding.urlInputField.setOnEditorActionListener { _, _, _ ->
            val url = binding.urlInputField.text.toString().trim()
            if (url.isNotEmpty()) loadVideo(url)
            true
        }
    }

    private fun loadVideo(url: String) {
        val videoId = YouTubeUrlParser.extractVideoId(url)
        if (videoId == null) {
            Toast.makeText(this, "無效的 YouTube 網址", Toast.LENGTH_SHORT).show()
            return
        }
        currentVideoId = videoId
        isVideoPaused = false
        val isLive = YouTubeUrlParser.isLiveStream(url)
        binding.webPlayer.loadUrl("https://www.youtube.com/watch?v=$videoId&autoplay=1")
        commentsFragment.loadComments(videoId)
        chatFragment.setVideoId(videoId, isLive)
        binding.tabLayout.isVisible = true
        binding.fragmentContainer.isVisible = true
        binding.btnPip.isVisible = true
        if (isLive) binding.tabLayout.selectTab(binding.tabLayout.getTabAt(1))
        else binding.tabLayout.selectTab(binding.tabLayout.getTabAt(0))
    }

    private fun setupThemeToggle() {
        binding.btnTheme.setOnClickListener {
            isDarkMode = !isDarkMode
            AppCompatDelegate.setDefaultNightMode(
                if (isDarkMode) AppCompatDelegate.MODE_NIGHT_YES
                else AppCompatDelegate.MODE_NIGHT_NO
            )
        }
    }

    private fun setupPipButton() {
        binding.btnPip.isVisible = false
        binding.btnPip.setOnClickListener { enterPipMode() }
    }

    private fun enterPipMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Get video ratio async, then enter PiP synchronously on main thread
            injectPipCss(binding.webPlayer) {
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        enterPictureInPictureMode(buildPipParams())
                    }
                }
            }
        }
    }

    private fun buildPipParams(): PictureInPictureParams {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            throw IllegalStateException("PiP requires API 26+")
        }
        val playPauseIntent = PendingIntent.getBroadcast(
            this, REQUEST_PLAY_PAUSE,
            Intent(ACTION_PLAY_PAUSE).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val icon = Icon.createWithResource(
            this,
            if (isVideoPaused) android.R.drawable.ic_media_play
            else android.R.drawable.ic_media_pause
        )
        val action = RemoteAction(
            icon,
            if (isVideoPaused) "播放" else "暫停",
            if (isVideoPaused) "播放" else "暫停",
            playPauseIntent
        )
        return PictureInPictureParams.Builder()
            .setAspectRatio(pipVideoRatio)
            .setActions(listOf(action))
            .build()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // onUserLeaveHint: Activity still resumed, can enter PiP directly
        // Skip async JS to avoid leaving resumed state before enterPictureInPictureMode
        if (currentVideoId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!isFinishing && !isDestroyed) {
                enterPictureInPictureMode(buildPipParams())
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean, newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            binding.topBar.visibility = View.GONE
            binding.urlInputCard.visibility = View.GONE
            binding.tabLayout.visibility = View.GONE
            binding.fragmentContainer.visibility = View.GONE

            val params = binding.webPlayer.layoutParams as ConstraintLayout.LayoutParams
            params.topToTop = ConstraintLayout.LayoutParams.PARENT_ID
            params.topToBottom = ConstraintLayout.LayoutParams.UNSET
            params.bottomToBottom = ConstraintLayout.LayoutParams.PARENT_ID
            params.dimensionRatio = null
            params.height = ConstraintLayout.LayoutParams.MATCH_CONSTRAINT
            binding.webPlayer.layoutParams = params
            binding.webPlayer.requestLayout()
        } else {
            removePipCss(binding.webPlayer)

            val params = binding.webPlayer.layoutParams as ConstraintLayout.LayoutParams
            params.topToTop = ConstraintLayout.LayoutParams.UNSET
            params.topToBottom = binding.topBar.id
            params.bottomToBottom = ConstraintLayout.LayoutParams.UNSET
            params.dimensionRatio = "16:9"
            params.height = ConstraintLayout.LayoutParams.MATCH_CONSTRAINT
            binding.webPlayer.layoutParams = params
            binding.webPlayer.requestLayout()

            binding.topBar.visibility = View.VISIBLE
            binding.urlInputCard.visibility = View.VISIBLE
            binding.tabLayout.isVisible = currentVideoId != null
            binding.fragmentContainer.isVisible = currentVideoId != null
        }
    }

    private fun setupTabs() {
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("💬 留言"))
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("🔴 聊天室"))
        binding.tabLayout.isVisible = false
        binding.tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                when (tab.position) {
                    0 -> showFragment(commentsFragment)
                    1 -> showFragment(chatFragment)
                }
            }
            override fun onTabUnselected(tab: TabLayout.Tab) {}
            override fun onTabReselected(tab: TabLayout.Tab) {}
        })
    }

    private fun setupFragments() {
        supportFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, commentsFragment)
            .add(R.id.fragmentContainer, chatFragment)
            .hide(chatFragment)
            .commit()
    }

    private fun showFragment(fragment: androidx.fragment.app.Fragment) {
        val transaction = supportFragmentManager.beginTransaction()
        supportFragmentManager.fragments.forEach { transaction.hide(it) }
        transaction.show(fragment)
        transaction.commit()
    }

    override fun onDestroy() {
        super.onDestroy()
        binding.webPlayer.destroy()
    }
}
KTEOF
cd "$REPO_ROOT"
git add -A
git commit -m "fix: PiP use actual video aspect ratio, fix Home crash"
git push
echo "✅ 完成！"
