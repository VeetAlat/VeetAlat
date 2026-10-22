#ifndef STHIGHLIGHTER_H
#define STHIGHLIGHTER_H

#include <QColor>
#include <QPointer>
#include <QQuickTextDocument>
#include <QSet>
#include <QStringList>
#include <QSyntaxHighlighter>

// Colours Structured Text in the editor: keywords, types, standard
// functions and function blocks, numbers and times, strings and comments,
// with a wavy underline on the line of the latest error. The word lists
// come from QML (st.js knows them), the colours from the theme.
class StHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *textDocument READ textDocument WRITE setTextDocument NOTIFY textDocumentChanged)
    Q_PROPERTY(QStringList keywords READ keywords WRITE setKeywords NOTIFY wordsChanged)
    Q_PROPERTY(QStringList types READ types WRITE setTypes NOTIFY wordsChanged)
    Q_PROPERTY(QStringList functions READ functions WRITE setFunctions NOTIFY wordsChanged)
    Q_PROPERTY(QColor keywordColor MEMBER m_keywordColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor typeColor MEMBER m_typeColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor functionColor MEMBER m_functionColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor literalColor MEMBER m_literalColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor stringColor MEMBER m_stringColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor commentColor MEMBER m_commentColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor errorColor MEMBER m_errorColor NOTIFY colorsChanged)
    Q_PROPERTY(int errorLine READ errorLine WRITE setErrorLine NOTIFY errorLineChanged)
    Q_PROPERTY(int highlightedBlocks READ highlightedBlocks NOTIFY highlighted)

public:
    explicit StHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *textDocument() const { return m_textDocument; }
    void setTextDocument(QQuickTextDocument *document);
    QStringList keywords() const { return m_keywords; }
    void setKeywords(const QStringList &words);
    QStringList types() const { return m_types; }
    void setTypes(const QStringList &words);
    QStringList functions() const { return m_functions; }
    void setFunctions(const QStringList &words);
    int errorLine() const { return m_errorLine; }
    void setErrorLine(int line);
    // How many lines have been coloured so far (for the tests).
    int highlightedBlocks() const { return m_highlightedBlocks; }

signals:
    void textDocumentChanged();
    void wordsChanged();
    void colorsChanged();
    void errorLineChanged();
    void highlighted();

protected:
    void highlightBlock(const QString &text) override;

private:
    QPointer<QQuickTextDocument> m_textDocument;
    QStringList m_keywords, m_types, m_functions;
    QSet<QString> m_keywordSet, m_typeSet, m_functionSet;
    QColor m_keywordColor, m_typeColor, m_functionColor, m_literalColor, m_stringColor,
           m_commentColor, m_errorColor;
    int m_errorLine = 0;
    int m_highlightedBlocks = 0;
};

#endif
