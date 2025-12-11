#pragma once

#include <QObject>
#include <QString>

class FileUtils : public QObject
{
    Q_OBJECT

public:
    explicit FileUtils(QObject *parent = nullptr);

    Q_INVOKABLE static bool fileExists(const QString &filePath);
    Q_INVOKABLE static QString getUniqueFileName(const QString &directory, const QString &fileName);
};
