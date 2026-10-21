// Reads a story page off the screen's thread: a big page takes a moment to
// pick apart, and this way scrolling never stutters while it does.
Qt.include("article.js")

WorkerScript.onMessage = function(message) {
    var reply = { url: message.url }
    try {
        reply.article = parseArticle(message.html, message.url)
    } catch (e) {
        reply.error = String(e)
    }
    WorkerScript.sendMessage(reply)
}
