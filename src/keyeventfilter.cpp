#include "keyeventfilter.h"

#include <QEvent>
#include <QKeyEvent>

KeyEventFilter::KeyEventFilter(QObject *parent)
    : QObject(parent)
    , m_ctrlWasPressed(false)
    , m_otherKeyPressed(false)
    , m_ctrlIsDown(false)
{
}

bool KeyEventFilter::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::KeyPress) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent *>(event);
        
        if (keyEvent->key() == Qt::Key_Control && !keyEvent->isAutoRepeat()) {
            m_ctrlIsDown = true;
        }
        // Track if any non-modifier key is pressed while Ctrl is held
        else if (keyEvent->key() != Qt::Key_Shift &&
                 keyEvent->key() != Qt::Key_Alt &&
                 keyEvent->key() != Qt::Key_Meta) {
            m_otherKeyPressed = true;
        }
    }
    else if (event->type() == QEvent::KeyRelease) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent *>(event);
        
        // Only process Ctrl key releases
        if (keyEvent->key() == Qt::Key_Control && !keyEvent->isAutoRepeat()) {
            // Only process if Ctrl was actually down (avoid duplicate events)
            if (m_ctrlIsDown) {
                m_ctrlIsDown = false;
                
                // Only trigger if no other key was pressed during this Ctrl press
                if (!m_otherKeyPressed) {
                    if (m_ctrlWasPressed && m_ctrlTimer.isValid() && 
                        m_ctrlTimer.elapsed() < DOUBLE_CTRL_INTERVAL &&
                        m_ctrlTimer.elapsed() > 50) {  // Minimum 50ms to avoid false positives
                        // Double Ctrl detected!
                        Q_EMIT doubleCtrlPressed();
                        m_ctrlWasPressed = false;
                        m_ctrlTimer.invalidate();
                    } else {
                        // First Ctrl release - start timer
                        m_ctrlWasPressed = true;
                        m_ctrlTimer.start();
                    }
                } else {
                    // Reset if other keys were pressed
                    m_ctrlWasPressed = false;
                    m_ctrlTimer.invalidate();
                }
                m_otherKeyPressed = false;
            }
        }
        else if (keyEvent->key() != Qt::Key_Shift &&
                 keyEvent->key() != Qt::Key_Alt &&
                 keyEvent->key() != Qt::Key_Meta) {
            // Reset on other key releases
            m_otherKeyPressed = false;
        }
    }
    
    // Don't consume the event - let it propagate normally
    return QObject::eventFilter(watched, event);
}
