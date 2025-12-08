#ifndef KEYEVENTFILTER_H
#define KEYEVENTFILTER_H

#include <QObject>
#include <QElapsedTimer>

class KeyEventFilter : public QObject
{
    Q_OBJECT

public:
    explicit KeyEventFilter(QObject *parent = nullptr);

Q_SIGNALS:
    void doubleCtrlPressed();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    QElapsedTimer m_ctrlTimer;
    bool m_ctrlWasPressed;
    bool m_otherKeyPressed;
    bool m_ctrlIsDown;
    static constexpr int DOUBLE_CTRL_INTERVAL = 400; // ms
};

#endif // KEYEVENTFILTER_H
