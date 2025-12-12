#pragma once

#include <QObject>
#include <QString>
#include <QByteArray>

class FileUtils : public QObject
{
    Q_OBJECT

public:
    explicit FileUtils(QObject *parent = nullptr);

    Q_INVOKABLE static bool fileExists(const QString &filePath);
    Q_INVOKABLE static QString getUniqueFileName(const QString &directory, const QString &fileName);
    Q_INVOKABLE static bool saveBinaryFile(const QString &filePath, const QByteArray &data);
};
