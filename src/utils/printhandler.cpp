#include "printhandler.h"
#include <QDebug>
#include <QPrintDialog>
#include <QPainter>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QPdfDocument>
#include <QRegularExpression>

PrintHandler::PrintHandler(QObject *parent)
    : QObject(parent)
    , m_printer(QPrinter::HighResolution)
{
}

QString PrintHandler::getTempPdfPath(const QString &serviceName)
{
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    QString safeServiceName = serviceName;
    safeServiceName.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9]")), QStringLiteral("_"));
    
    return QStringLiteral("%1/unify_print_%2_%3.pdf").arg(tempDir, safeServiceName, timestamp);
}

void PrintHandler::printPdf(const QString &pdfFilePath)
{
    qDebug() << "🖨️ Opening print dialog for:" << pdfFilePath;

    QPdfDocument pdfDoc;
    auto loadError = pdfDoc.load(pdfFilePath);
    if (loadError != QPdfDocument::Error::None) {
        qWarning() << "❌ Failed to load PDF:" << pdfFilePath;
        Q_EMIT printCompleted(false);
        return;
    }

    int pageCount = pdfDoc.pageCount();
    if (pageCount == 0) {
        qWarning() << "❌ PDF has no pages";
        Q_EMIT printCompleted(false);
        return;
    }

    qDebug() << "🖨️ PDF loaded with" << pageCount << "pages";

    m_printer.setResolution(300);
    
    QPrintDialog dialog(&m_printer, nullptr);
    dialog.setWindowTitle(tr("Print Document"));
    dialog.setOption(QAbstractPrintDialog::PrintToFile, false);

    if (dialog.exec() != QDialog::Accepted) {
        qDebug() << "🖨️ Print dialog cancelled";
        Q_EMIT printCompleted(false);
        return;
    }

    qDebug() << "🖨️ Printing" << pageCount << "pages...";

    QPainter painter;
    if (!painter.begin(&m_printer)) {
        qWarning() << "❌ Failed to start printing";
        Q_EMIT printCompleted(false);
        return;
    }

    QRect pageRect = m_printer.pageLayout().paintRectPixels(m_printer.resolution());

    for (int i = 0; i < pageCount; ++i) {
        if (i > 0) {
            m_printer.newPage();
        }

        QSizeF pdfPageSize = pdfDoc.pagePointSize(i);
        QImage pageImage = pdfDoc.render(i, pdfPageSize.toSize() * 4);
        
        if (pageImage.isNull()) {
            qWarning() << "❌ Failed to render page" << i;
            continue;
        }

        QImage scaledImage = pageImage.scaled(pageRect.size(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
        
        int x = (pageRect.width() - scaledImage.width()) / 2;
        int y = (pageRect.height() - scaledImage.height()) / 2;
        
        painter.drawImage(x, y, scaledImage);
    }

    painter.end();

    qDebug() << "✅ Print completed successfully";
    Q_EMIT printCompleted(true);
}
