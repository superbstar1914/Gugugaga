package com.ytviewer.utils

object YouTubeUrlParser {

    fun extractVideoId(url: String): String? {
        // Standard watch URL: https://www.youtube.com/watch?v=VIDEO_ID
        val watchRegex = Regex("""[?&]v=([a-zA-Z0-9_-]{11})""")
        watchRegex.find(url)?.groupValues?.get(1)?.let { return it }

        // Short URL: https://youtu.be/VIDEO_ID
        val shortRegex = Regex("""youtu\.be/([a-zA-Z0-9_-]{11})""")
        shortRegex.find(url)?.groupValues?.get(1)?.let { return it }

        // Embed URL: https://www.youtube.com/embed/VIDEO_ID
        val embedRegex = Regex("""youtube\.com/embed/([a-zA-Z0-9_-]{11})""")
        embedRegex.find(url)?.groupValues?.get(1)?.let { return it }

        // Live URL: https://www.youtube.com/live/VIDEO_ID
        val liveRegex = Regex("""youtube\.com/live/([a-zA-Z0-9_-]{11})""")
        liveRegex.find(url)?.groupValues?.get(1)?.let { return it }

        // Shorts: https://www.youtube.com/shorts/VIDEO_ID
        val shortsRegex = Regex("""youtube\.com/shorts/([a-zA-Z0-9_-]{11})""")
        shortsRegex.find(url)?.groupValues?.get(1)?.let { return it }

        // If it looks like a raw video ID (11 chars, alphanumeric + _ -)
        if (url.matches(Regex("""[a-zA-Z0-9_-]{11}"""))) {
            return url
        }

        return null
    }

    fun isLiveStream(url: String): Boolean {
        return url.contains("/live/") ||
               url.contains("live_stream") ||
               url.contains("&live=1") ||
               url.contains("?live=1")
    }

    fun getLiveChatEmbedUrl(videoId: String): String {
        return "https://www.youtube.com/live_chat?v=$videoId&embed_domain=youtube.com&is_popout=1"
    }
}
