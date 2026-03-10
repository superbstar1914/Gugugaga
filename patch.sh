#!/bin/bash
# 在 Codespace 終端機執行這個腳本，自動更新所有修改的檔案
# 使用方法：bash patch.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP="$REPO_ROOT/YTViewer/app/src/main"

echo "📁 Repo root: $REPO_ROOT"

# =====================
# MainActivity.kt
# =====================
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
            if (intent?.action == ACTION_PLAY_PAUSE) togglePlayPause()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

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
                Object.defineProperty(document, 'hidden', { get: function(){ return false; }, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: function(){ return 'visible'; }, configurable: true });
                document.addEventListener('visibilitychange', function(e){ e.stopImmediatePropagation(); }, true);
                document.addEventListener('click', function() { window._lastTouch = Date.now(); }, true);
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
                new MutationObserver(function() {
                    var v = document.querySelector('video');
                    if (v) patchVideo(v);
                }).observe(document.documentElement, { childList: true, subtree: true });
                var v = document.querySelector('video');
                if (v) patchVideo(v);
            })();
        """.trimIndent(), null)
    }

    private fun injectPipCss(view: WebView?, callback: (() -> Unit)? = null) {
        view?.evaluateJavascript("""
            (function() {
                var CSS = '#masthead-container,ytd-masthead,#masthead,.ytp-chrome-top,.ytp-chrome-bottom,#below,#secondary,#comments,#panels { display:none !important; } video { position:fixed !important; top:0 !important; left:0 !important; width:100vw !important; height:100vh !important; z-index:99999 !important; background:#000 !important; object-fit:contain !important; } body,html { background:#000 !important; overflow:hidden !important; margin:0 !important; padding:0 !important; }';
                var s = document.getElementById('pip-hide') || document.createElement('style');
                s.id = 'pip-hide';
                s.innerHTML = CSS;
                document.head.appendChild(s);
                var v = document.querySelector('video');
                if (v) v.play();
                return 'ok';
            })();
        """.trimIndent()) { callback?.invoke() }
    }

    private fun removePipCss(view: WebView?) {
        view?.evaluateJavascript("document.getElementById('pip-hide')?.remove();", null)
    }

    private fun togglePlayPause() {
        binding.webPlayer.evaluateJavascript("""
            (function() {
                window._lastTouch = Date.now();
                var v = document.querySelector('video');
                if (v) { if (v.paused) v.play(); else v.pause(); }
            })();
        """.trimIndent(), null)
        isVideoPaused = !isVideoPaused
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
            injectPipCss(binding.webPlayer) {
                binding.root.postDelayed({
                    if (!isFinishing && !isDestroyed) {
                        enterPictureInPictureMode(buildPipParams())
                    }
                }, 150)
            }
        }
    }

    private fun buildPipParams(): PictureInPictureParams {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) throw IllegalStateException()
        val intent = PendingIntent.getBroadcast(
            this, REQUEST_PLAY_PAUSE,
            Intent(ACTION_PLAY_PAUSE).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val icon = Icon.createWithResource(this,
            if (isVideoPaused) android.R.drawable.ic_media_play
            else android.R.drawable.ic_media_pause)
        val action = RemoteAction(icon,
            if (isVideoPaused) "播放" else "暫停",
            if (isVideoPaused) "播放" else "暫停", intent)
        return PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(listOf(action))
            .build()
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

# =====================
# activity_main.xml
# =====================
cat > "$APP/res/layout/activity_main.xml" << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#121212">

    <LinearLayout
        android:id="@+id/topBar"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical"
        android:paddingStart="12dp"
        android:paddingEnd="12dp"
        android:paddingBottom="8dp"
        android:minHeight="56dp"
        android:background="#1E1E1E"
        android:elevation="4dp"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent">

        <TextView
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="&#9654; YTViewer"
            android:textSize="20sp"
            android:textStyle="bold"
            android:textColor="#FFFFFF"
            android:fontFamily="monospace" />

        <com.google.android.material.button.MaterialButton
            android:id="@+id/btnPip"
            style="@style/Widget.MaterialComponents.Button.OutlinedButton"
            android:layout_width="wrap_content"
            android:layout_height="36dp"
            android:text="PIP"
            android:textSize="11sp"
            android:visibility="gone"
            android:layout_marginEnd="8dp" />

        <com.google.android.material.button.MaterialButton
            android:id="@+id/btnTheme"
            style="@style/Widget.MaterialComponents.Button.TextButton"
            android:layout_width="40dp"
            android:layout_height="40dp"
            app:icon="@drawable/ic_dark_mode"
            app:iconSize="22dp"
            app:iconPadding="0dp"
            android:padding="0dp"
            android:minWidth="0dp" />

    </LinearLayout>

    <WebView
        android:id="@+id/webPlayer"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        app:layout_constraintTop_toBottomOf="@id/topBar"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintDimensionRatio="16:9" />

    <com.google.android.material.card.MaterialCardView
        android:id="@+id/urlInputCard"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginStart="12dp"
        android:layout_marginEnd="12dp"
        android:layout_marginTop="10dp"
        app:cardCornerRadius="12dp"
        app:cardElevation="3dp"
        app:cardBackgroundColor="#1E1E1E"
        app:layout_constraintTop_toBottomOf="@id/webPlayer"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:padding="10dp"
            android:gravity="center_vertical">

            <com.google.android.material.textfield.TextInputLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                style="@style/Widget.MaterialComponents.TextInputLayout.OutlinedBox"
                android:hint="貼上 YouTube 影片 / 直播網址"
                android:layout_marginEnd="8dp">

                <com.google.android.material.textfield.TextInputEditText
                    android:id="@+id/urlInputField"
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:inputType="textUri"
                    android:imeOptions="actionGo"
                    android:maxLines="1"
                    android:textSize="13sp"
                    android:textColor="#FFFFFF" />

            </com.google.android.material.textfield.TextInputLayout>

            <com.google.android.material.button.MaterialButton
                android:id="@+id/btnLoad"
                android:layout_width="wrap_content"
                android:layout_height="48dp"
                android:text="載入"
                android:textSize="13sp"
                app:cornerRadius="8dp" />

        </LinearLayout>
    </com.google.android.material.card.MaterialCardView>

    <com.google.android.material.tabs.TabLayout
        android:id="@+id/tabLayout"
        android:layout_width="match_parent"
        android:layout_height="48dp"
        android:layout_marginTop="8dp"
        app:tabMode="fixed"
        app:tabGravity="fill"
        app:layout_constraintTop_toBottomOf="@id/urlInputCard"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:visibility="gone" />

    <FrameLayout
        android:id="@+id/fragmentContainer"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        app:layout_constraintTop_toBottomOf="@id/tabLayout"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:visibility="gone" />

</androidx.constraintlayout.widget.ConstraintLayout>
XMLEOF

echo ""
echo "✅ 所有檔案更新完成！"
echo ""
echo "現在執行："
echo "  cd $(git rev-parse --show-toplevel)/YTViewer && git add -A && git commit -m 'fix: status bar, PiP CSS, pause logic' && git push"
