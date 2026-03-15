#ifndef KEYEVENTFILTER_H
#define KEYEVENTFILTER_H

#include <QElapsedTimer>
#include <QObject>

class KeyEventFilter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ctrlPressed READ ctrlPressed NOTIFY ctrlPressedChanged)

public:
    explicit KeyEventFilter(QObject *parent = nullptr);
    bool ctrlPressed() const;

Q_SIGNALS:
    void doubleCtrlPressed();
    void ctrlPressedChanged();

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
