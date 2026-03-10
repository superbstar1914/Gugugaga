package com.ytviewer

import android.annotation.SuppressLint
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Rational
import android.view.MotionEvent
import android.view.View
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
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
    private val touchWindowMs = 1500L // 1.5秒內有碰過才算使用者暫停

    private val commentsFragment = CommentsFragment()
    private val chatFragment = ChatFragment()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupWebPlayer()
        setupUrlInput()
        setupThemeToggle()
        setupPipButton()
        setupTabs()
        setupFragments()
        handleIntent(intent)
        // 預設載入 rickroll，延遲等 Fragment view 建立完成
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

        // 記錄最後一次碰觸時間
        binding.webPlayer.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN ||
                event.action == MotionEvent.ACTION_MOVE) {
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
                injectAntiPauseJs(view)
            }
        }
    }

    private fun injectAntiPauseJs(view: WebView?) {
        // touchWindowMs 傳入 JS，暫停發生時若距離上次觸碰超過這個時間就阻擋
        view?.evaluateJavascript("""
            (function() {
                var TOUCH_WINDOW = $touchWindowMs;
                var lastTouch = 0;

                // Android 端的 touch 時間會透過 interface 傳入，
                // 這裡改用 pointerdown 自行追蹤
                document.addEventListener('pointerdown', function() {
                    lastTouch = Date.now();
                }, true);

                // Override visibility API
                Object.defineProperty(document, 'hidden', { get: function(){ return false; }, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: function(){ return 'visible'; }, configurable: true });
                document.addEventListener('visibilitychange', function(e){ e.stopImmediatePropagation(); }, true);

                function patchVideo(video) {
                    if (video._patched) return;
                    video._patched = true;
                    video.addEventListener('pause', function() {
                        var timeSinceTouch = Date.now() - lastTouch;
                        // 300ms 內有碰過才是使用者主動暫停，否則是系統暫停要阻擋
                        if (timeSinceTouch > 300) {
                            setTimeout(function(){ if(video.paused) video.play(); }, 80);
                        }
                    });
                }

                // 立刻 patch 現有 video
                var v = document.querySelector('video');
                if (v) patchVideo(v);

                // 每 2 秒檢查有沒有新的 video 出現
                var tries = 0;
                var interval = setInterval(function() {
                    var v2 = document.querySelector('video');
                    if (v2) patchVideo(v2);
                    if (++tries > 15) clearInterval(interval);
                }, 2000);
            })();
        """.trimIndent(), null)
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
            binding.webPlayer.evaluateJavascript("""
                (function() {
                    var v = document.querySelector('video');
                    if (v) v.play();
                    // Theatre mode: hide all YouTube chrome so only video shows in PiP
                    var s = document.getElementById('pip-style');
                    if (!s) {
                        s = document.createElement('style');
                        s.id = 'pip-style';
                        s.innerHTML = '#masthead-container, .ytp-chrome-top, .ytp-chrome-bottom, #below, #secondary, #comments, ytd-masthead, #page-manager > ytd-watch-flexy #secondary, ytd-watch-flexy #below { display: none !important; } video { width: 100vw !important; height: 100vh !important; object-fit: contain; position: fixed !important; top:0 !important; left:0 !important; z-index:99999; background:#000; }';
                        document.head.appendChild(s);
                    }
                })();
            """.trimIndent(), null)
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(pipParams)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (currentVideoId != null) enterPipMode()
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

            binding.webPlayer.evaluateJavascript("""
                (function() {
                    var s = document.getElementById('pip-style');
                    if (s) s.remove();
                })();
            """.trimIndent(), null)
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
