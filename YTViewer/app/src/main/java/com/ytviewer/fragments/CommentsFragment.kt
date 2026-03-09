package com.ytviewer.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.ytviewer.R
import com.ytviewer.models.Comment
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.URL

class CommentsFragment : Fragment() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var tvEmpty: TextView
    private lateinit var tvLoading: TextView
    private val comments = mutableListOf<Comment>()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_comments, container, false)
        recyclerView = view.findViewById(R.id.rvComments)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        tvLoading = view.findViewById(R.id.tvLoading)

        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = CommentsAdapter(comments)
        return view
    }

    fun loadComments(videoId: String) {
        tvLoading.visibility = View.VISIBLE
        tvEmpty.visibility = View.GONE
        recyclerView.visibility = View.GONE
        comments.clear()
        recyclerView.adapter?.notifyDataSetChanged()

        // Note: YouTube Data API v3 requires an API key.
        // This shows the structure - user needs to add their API key.
        // For demo, show placeholder comments.
        scope.launch {
            delay(800)
            val demoComments = listOf(
                Comment("1", "Viewer_1", "", "這個影片真的很棒！謝謝分享 👍", 42, "2024-01-01"),
                Comment("2", "User_ABC", "", "第一次看到這麼精彩的內容，訂閱了！", 38, "2024-01-01"),
                Comment("3", "YT_Fan", "", "求更多類似的影片！", 25, "2024-01-01"),
                Comment("4", "Watcher_X", "", "這個解釋讓我茅塞頓開，感謝！", 19, "2024-01-01"),
                Comment("5", "Channel_Pro", "", "製作品質非常好，繼續加油！💪", 15, "2024-01-01"),
                Comment("6", "NewViewer", "", "從朋友那裡推薦過來的，果然沒讓我失望", 12, "2024-01-01"),
                Comment("7", "Regular_Fan", "", "每次都在等你的更新！", 8, "2024-01-01"),
                Comment("8", "Tech_Lover", "", "技術含量很高，學到很多 🎓", 7, "2024-01-01"),
            )
            comments.addAll(demoComments)
            tvLoading.visibility = View.GONE

            if (comments.isEmpty()) {
                tvEmpty.visibility = View.VISIBLE
                tvEmpty.text = "⚠️ 需要 YouTube API Key 才能顯示留言\n請在設定中加入 API Key"
            } else {
                recyclerView.visibility = View.VISIBLE
                recyclerView.adapter?.notifyDataSetChanged()
                showApiKeyNote()
            }
        }
    }

    private fun showApiKeyNote() {
        tvEmpty.visibility = View.VISIBLE
        tvEmpty.text = "📌 目前顯示範例留言。\n設定 YouTube Data API Key 可顯示真實留言。"
        tvEmpty.setCompoundDrawablesWithIntrinsicBounds(0, 0, 0, 0)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        scope.cancel()
    }
}

class CommentsAdapter(private val comments: List<Comment>) :
    RecyclerView.Adapter<CommentsAdapter.CommentViewHolder>() {

    class CommentViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvAuthor: TextView = view.findViewById(R.id.tvAuthor)
        val tvComment: TextView = view.findViewById(R.id.tvComment)
        val tvLikes: TextView = view.findViewById(R.id.tvLikes)
        val tvDate: TextView = view.findViewById(R.id.tvDate)
        val ivAvatar: ImageView = view.findViewById(R.id.ivAvatar)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CommentViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_comment, parent, false)
        return CommentViewHolder(view)
    }

    override fun onBindViewHolder(holder: CommentViewHolder, position: Int) {
        val comment = comments[position]
        holder.tvAuthor.text = comment.authorName
        holder.tvComment.text = comment.text
        holder.tvLikes.text = "👍 ${comment.likeCount}"
        holder.tvDate.text = comment.publishedAt

        if (comment.authorAvatar.isNotEmpty()) {
            Glide.with(holder.itemView.context)
                .load(comment.authorAvatar)
                .circleCrop()
                .placeholder(R.drawable.ic_person)
                .into(holder.ivAvatar)
        } else {
            holder.ivAvatar.setImageResource(R.drawable.ic_person)
        }
    }

    override fun getItemCount() = comments.size
}
