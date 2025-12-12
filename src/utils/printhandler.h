#pragma once

#include <QObject>
#include <QPrinter>
#include <QString>

class PrintHandler : public QObject
{
    Q_OBJECT

public:
    explicit PrintHandler(QObject *parent = nullptr);

    Q_INVOKABLE void printPdf(const QString &pdfFilePath);
    Q_INVOKABLE QString getTempPdfPath(const QString &serviceName);

Q_SIGNALS:
    void printCompleted(bool success);

private:
    QPrinter m_printer;
};
