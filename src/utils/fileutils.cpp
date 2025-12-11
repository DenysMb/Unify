#include "fileutils.h"
#include <QFile>
#include <QFileInfo>

FileUtils::FileUtils(QObject *parent)
    : QObject(parent)
{
}

bool FileUtils::fileExists(const QString &filePath)
{
    return QFile::exists(filePath);
}

QString FileUtils::getUniqueFileName(const QString &directory, const QString &fileName)
{
    QString baseName = fileName;
    QString extension;
    
    // Split filename and extension
    int lastDot = fileName.lastIndexOf(QLatin1Char('.'));
    if (lastDot > 0) {
        baseName = fileName.left(lastDot);
        extension = fileName.mid(lastDot);
    }
    
    // Check if file exists and find available name
    QString uniqueName = fileName;
    int counter = 1;
    
    QString fullPath = QStringLiteral("%1/%2").arg(directory, uniqueName);
    while (QFile::exists(fullPath)) {
        uniqueName = QStringLiteral("%1 (%2)%3").arg(baseName).arg(counter).arg(extension);
        fullPath = QStringLiteral("%1/%2").arg(directory, uniqueName);
        counter++;
    }
    
    return uniqueName;
}
