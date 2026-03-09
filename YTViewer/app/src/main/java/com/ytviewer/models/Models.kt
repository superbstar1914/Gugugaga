package com.ytviewer.models

data class Comment(
    val id: String,
    val authorName: String,
    val authorAvatar: String,
    val text: String,
    val likeCount: Int,
    val publishedAt: String,
    val isTopLevel: Boolean = true
)

data class ChatMessage(
    val id: String,
    val authorName: String,
    val authorAvatar: String,
    val message: String,
    val timestamp: Long,
    val badgeColor: String? = null // for superchat/membership
)
