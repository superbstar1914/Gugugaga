# YTViewer - Android YouTube 播放器

一個功能完整的 Android YouTube 播放器，支援子母畫面、直播聊天室、留言顯示，以及亮色/暗色模式切換。

---

## ✨ 功能特色

| 功能 | 說明 |
|------|------|
| 📺 影片播放 | 使用官方 YouTubePlayer SDK，支援所有 YouTube 影片格式 |
| 🔴 直播播放 | 支援 YouTube 直播網址 |
| 💬 留言顯示 | 顯示影片留言（需 YouTube Data API Key） |
| 🗨️ 聊天室 | 嵌入直播聊天室（WebView） |
| 📱 子母畫面 | 按 PIP 按鈕或切換到其他 App 自動觸發 |
| 🌙 暗色模式 | 右上角按鈕一鍵切換亮/暗色主題 |
| 🔗 分享支援 | 從 YouTube App 分享網址直接在此播放 |

---

## 🚀 安裝步驟

### 環境需求
- Android Studio Hedgehog 或以上版本
- JDK 17
- Android SDK 26+（minSdk 26）

### 1. 匯入專案
```bash
# 用 Android Studio 開啟此資料夾
File → Open → 選擇 YTViewer 資料夾
```

### 2. Gradle Sync
Android Studio 會自動執行 Gradle Sync，下載所有依賴套件。

### 3. 建置並執行
```
Run → Run 'app'  (或按 Shift+F10)
```

---

## 📱 支援的網址格式

```
https://www.youtube.com/watch?v=VIDEO_ID       ← 一般影片
https://youtu.be/VIDEO_ID                       ← 短網址
https://www.youtube.com/live/VIDEO_ID           ← 直播
https://www.youtube.com/shorts/VIDEO_ID         ← Shorts
https://www.youtube.com/embed/VIDEO_ID          ← 嵌入
VIDEO_ID                                        ← 直接輸入 ID
```

---

## 🔑 YouTube Data API Key 設定（可選，顯示真實留言）

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立專案 → 啟用 **YouTube Data API v3**
3. 建立 API Key（Credentials → API Key）
4. 在 `CommentsFragment.kt` 中找到以下位置：

```kotlin
// 在 loadComments() 函式中，替換 demo 留言為真實 API 呼叫
val apiKey = "YOUR_API_KEY_HERE"
val url = "https://www.googleapis.com/youtube/v3/commentThreads" +
          "?part=snippet&videoId=$videoId&maxResults=50&key=$apiKey"
```

5. 加入 HTTP 請求邏輯解析 JSON 回傳值

---

## 📐 架構說明

```
YTViewer/
├── app/src/main/
│   ├── java/com/ytviewer/
│   │   ├── MainActivity.kt          ← 主畫面，PIP 控制，主題切換
│   │   ├── fragments/
│   │   │   ├── CommentsFragment.kt  ← 留言列表 (RecyclerView)
│   │   │   └── ChatFragment.kt      ← 直播聊天室 (WebView)
│   │   ├── models/
│   │   │   └── Models.kt            ← Comment / ChatMessage 資料模型
│   │   └── utils/
│   │       └── YouTubeUrlParser.kt  ← URL 解析工具
│   └── res/
│       ├── layout/                  ← 所有畫面 XML
│       ├── values/themes.xml        ← 亮色主題
│       └── values-night/themes.xml  ← 暗色主題
```

---

## 🎮 操作說明

### 播放影片
1. 在輸入框貼上 YouTube 網址
2. 點擊「載入」按鈕（或按鍵盤 Go 鍵）

### 子母畫面 (PiP)
- 方法一：載入影片後，點擊右上角 **PIP** 按鈕
- 方法二：播放中按 **Home 鍵** 或 **返回鍵** → 自動進入子母畫面

### 切換主題
- 點擊右上角 **🌙/☀️** 圖示

### 查看留言 / 聊天室
- 載入影片後，下方出現「💬 留言」和「🔴 聊天室」分頁
- 直播網址自動切換到聊天室分頁

---

## 📦 使用的依賴套件

| 套件 | 用途 |
|------|------|
| `pierfrancescosoffritti/androidyoutubeplayer` | YouTube 播放器 SDK |
| `Material Components` | UI 元件 (Card, Button, TabLayout) |
| `Glide` | 頭像圖片載入 |
| `Retrofit2` | （預留 API 呼叫用） |
| `Coroutines` | 非同步處理 |

---

## ⚠️ 注意事項

- 子母畫面需要 Android 8.0 (API 26) 以上
- 直播聊天室透過 WebView 嵌入 YouTube 官方介面
- 真實留言顯示需要 YouTube Data API Key（有每日配額限制）
- 請遵守 YouTube 服務條款使用本應用程式
