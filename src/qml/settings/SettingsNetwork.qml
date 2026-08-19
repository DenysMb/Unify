import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Network")

    Kirigami.ColumnView.fillWidth: true

    function isValidHost(host) {
        return /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/i.test(host);
    }

    function addHost(host) {
        if (!configManager) return;
        var normalized = host.trim().toLowerCase();
        if (!isValidHost(normalized)) return;
        var hosts = configManager.tlsProxyHosts.slice();
        if (hosts.indexOf(normalized) !== -1) return;
        hosts.push(normalized);
        configManager.tlsProxyHosts = hosts;
    }

    function removeHost(host) {
        if (!configManager) return;
        configManager.tlsProxyHosts = configManager.tlsProxyHosts.filter(function (h) {
            return h !== host;
        });
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "TLS Proxy:")
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18nc("@info", "Some APIs are protected by Cloudflare's TLS fingerprint detection, which blocks embedded browsers. Requests to the hosts below are routed through a local proxy that presents a real browser fingerprint. Status: %1", tlsProxyBridge && tlsProxyBridge.proxyReady ? i18nc("@info", "proxy active") : i18nc("@info", "proxy inactive"))
        }

        Repeater {
            model: configManager ? configManager.tlsProxyHosts : []

            delegate: RowLayout {
                required property string modelData
                required property int index

                Kirigami.FormData.label: index === 0 ? i18nc("@label", "Proxied Hosts:") : ""
                Layout.fillWidth: true

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData
                    elide: Text.ElideRight
                }

                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: root.removeHost(modelData)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nc("@action:button", "Remove host")
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: configManager && configManager.tlsProxyHosts.length === 0 ? i18nc("@label", "Proxied Hosts:") : ""

            QQC2.TextField {
                id: newHostField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "e.g., api.example.com")
                onAccepted: {
                    root.addHost(text);
                    text = "";
                }
            }

            QQC2.Button {
                text: i18nc("@action:button", "Add")
                enabled: root.isValidHost(newHostField.text.trim())
                onClicked: {
                    root.addHost(newHostField.text);
                    newHostField.text = "";
                }
            }
        }

        Kirigami.Separator {
            visible: suggestionsLabel.visible
            Kirigami.FormData.label: i18nc("@title:group", "Detected Hosts:")
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            id: suggestionsLabel
            visible: tlsProxyBridge && tlsProxyBridge.learnedHosts.length > 0
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18nc("@info", "These hosts failed with a network error and only worked through the proxy. Add them to skip the failed first attempt:")
        }

        Repeater {
            model: tlsProxyBridge ? tlsProxyBridge.learnedHosts : []

            delegate: RowLayout {
                required property string modelData

                Layout.fillWidth: true
                visible: suggestionsLabel.visible

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData
                    elide: Text.ElideRight
                }

                QQC2.Button {
                    text: i18nc("@action:button", "Add")
                    onClicked: {
                        root.addHost(modelData);
                        tlsProxyBridge.dismissLearnedHost(modelData);
                    }
                }

                QQC2.ToolButton {
                    icon.name: "dialog-close"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: tlsProxyBridge.dismissLearnedHost(modelData)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nc("@action:button", "Dismiss")
                }
            }
        }
    }
}
