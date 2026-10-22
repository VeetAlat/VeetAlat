#include "sthighlighter.h"

#include <QTextCharFormat>
#include <QTextDocument>

namespace {
// Block states: inside a (* *) comment (its nesting depth), or a /* */ one.
const int BlockComment = 1000;

QSet<QString> upperSet(const QStringList &words)
{
    QSet<QString> set;
    for (const QString &w : words)
        set.insert(w.toUpper());
    return set;
}

bool isIdentStart(QChar c) { return c.isLetter() || c == QLatin1Char('_'); }
bool isIdentChar(QChar c) { return c.isLetterOrNumber() || c == QLatin1Char('_'); }
}

// Qt 5.6's QSyntaxHighlighter(QObject *) dereferences its parent without
// checking it (QML creates objects without one), so this starts from the
// QTextDocument constructor, which takes a null document fine.
StHighlighter::StHighlighter(QObject *parent)
    : QSyntaxHighlighter(static_cast<QTextDocument *>(nullptr)),
      m_keywordColor(QStringLiteral("#ffcc66")), m_typeColor(QStringLiteral("#66ccff")),
      m_functionColor(QStringLiteral("#99e699")), m_literalColor(QStringLiteral("#ff99cc")),
      m_stringColor(QStringLiteral("#ffb380")), m_commentColor(QStringLiteral("#999999")),
      m_errorColor(QStringLiteral("#ff4d4d"))
{
    if (parent)
        setParent(parent);
    connect(this, &StHighlighter::colorsChanged, this, &QSyntaxHighlighter::rehighlight);
    connect(this, &StHighlighter::wordsChanged, this, &QSyntaxHighlighter::rehighlight);
}

void StHighlighter::setTextDocument(QQuickTextDocument *document)
{
    if (document == m_textDocument)
        return;
    m_textDocument = document;
    setDocument(document ? document->textDocument() : nullptr);
    emit textDocumentChanged();
}

void StHighlighter::setKeywords(const QStringList &words)
{
    m_keywords = words;
    m_keywordSet = upperSet(words);
    emit wordsChanged();
}

void StHighlighter::setTypes(const QStringList &words)
{
    m_types = words;
    m_typeSet = upperSet(words);
    emit wordsChanged();
}

void StHighlighter::setFunctions(const QStringList &words)
{
    m_functions = words;
    m_functionSet = upperSet(words);
    emit wordsChanged();
}

void StHighlighter::setErrorLine(int line)
{
    if (line == m_errorLine)
        return;
    const int old = m_errorLine;
    m_errorLine = line;
    if (document()) {
        // Only the two lines concerned.
        if (old > 0) {
            QTextBlock b = document()->findBlockByNumber(old - 1);
            if (b.isValid())
                rehighlightBlock(b);
        }
        if (line > 0) {
            QTextBlock b = document()->findBlockByNumber(line - 1);
            if (b.isValid())
                rehighlightBlock(b);
        }
    }
    emit errorLineChanged();
}

void StHighlighter::highlightBlock(const QString &text)
{
    QTextCharFormat keyword, type, function, literal, string, comment;
    keyword.setForeground(m_keywordColor);
    keyword.setFontWeight(QFont::Bold);
    type.setForeground(m_typeColor);
    function.setForeground(m_functionColor);
    literal.setForeground(m_literalColor);
    string.setForeground(m_stringColor);
    comment.setForeground(m_commentColor);
    comment.setFontItalic(true);

    const int n = text.length();
    int i = 0;
    int state = previousBlockState();
    int depth = state > 0 && state < BlockComment ? state : 0;
    bool slashComment = state == BlockComment;

    // A comment carried over from the line before.
    if (depth > 0 || slashComment) {
        int j = 0;
        while (j < n && (depth > 0 || slashComment)) {
            if (slashComment && text.midRef(j, 2) == QLatin1String("*/")) { slashComment = false; j += 2; }
            else if (!slashComment && text.midRef(j, 2) == QLatin1String("(*")) { depth++; j += 2; }
            else if (!slashComment && text.midRef(j, 2) == QLatin1String("*)")) { depth--; j += 2; }
            else j++;
        }
        setFormat(0, j, comment);
        i = j;
    }

    while (i < n) {
        const QChar c = text.at(i);
        if (text.midRef(i, 2) == QLatin1String("(*")) {
            int j = i + 2;
            depth = 1;
            while (j < n && depth > 0) {
                if (text.midRef(j, 2) == QLatin1String("(*")) { depth++; j += 2; }
                else if (text.midRef(j, 2) == QLatin1String("*)")) { depth--; j += 2; }
                else j++;
            }
            setFormat(i, j - i, comment);
            i = j;
            continue;
        }
        if (text.midRef(i, 2) == QLatin1String("/*")) {
            int end = text.indexOf(QLatin1String("*/"), i + 2);
            if (end < 0) { setFormat(i, n - i, comment); slashComment = true; i = n; }
            else { setFormat(i, end + 2 - i, comment); i = end + 2; }
            continue;
        }
        if (text.midRef(i, 2) == QLatin1String("//")) {
            setFormat(i, n - i, comment);
            break;
        }
        if (c == QLatin1Char('\'') || c == QLatin1Char('"')) {
            int j = i + 1;
            while (j < n && text.at(j) != c) {
                if (text.at(j) == QLatin1Char('$')) j++;
                j++;
            }
            setFormat(i, qMin(n, j + 1) - i, string);
            i = j + 1;
            continue;
        }
        if (c.isDigit()) {
            int j = i;
            while (j < n && (isIdentChar(text.at(j)) || text.at(j) == QLatin1Char('#')
                             || (text.at(j) == QLatin1Char('.') && j + 1 < n && text.at(j + 1).isDigit())))
                j++;
            setFormat(i, j - i, literal);
            i = j;
            continue;
        }
        if (isIdentStart(c)) {
            int j = i;
            while (j < n && isIdentChar(text.at(j)))
                j++;
            const QString word = text.mid(i, j - i).toUpper();
            // T#1s, TIME#..., INT#5: one literal.
            if (j < n && text.at(j) == QLatin1Char('#')) {
                int k = j + 1;
                while (k < n && (isIdentChar(text.at(k)) || text.at(k) == QLatin1Char('.') || text.at(k) == QLatin1Char('-')))
                    k++;
                setFormat(i, k - i, literal);
                i = k;
                continue;
            }
            if (word == QLatin1String("TRUE") || word == QLatin1String("FALSE"))
                setFormat(i, j - i, literal);
            else if (m_keywordSet.contains(word))
                setFormat(i, j - i, keyword);
            else if (m_typeSet.contains(word))
                setFormat(i, j - i, type);
            else if (m_functionSet.contains(word) || word.contains(QLatin1String("_TO_")) || word.startsWith(QLatin1String("TO_")))
                setFormat(i, j - i, function);
            i = j;
            continue;
        }
        i++;
    }

    setCurrentBlockState(slashComment ? BlockComment : depth);

    if (m_errorLine > 0 && currentBlock().blockNumber() == m_errorLine - 1) {
        for (int k = 0; k < qMax(1, n); k++) {
            QTextCharFormat f = format(k);
            f.setUnderlineStyle(QTextCharFormat::WaveUnderline);
            f.setUnderlineColor(m_errorColor);
            setFormat(k, 1, f);
        }
    }

    m_highlightedBlocks++;
    emit highlighted();
}
