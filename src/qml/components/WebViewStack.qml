import QtQuick
import QtQuick.Layouts
import QtWebEngine

import "./" as Components
import org.kde.kirigami as Kirigami

StackLayout {
    id: root

    // Public API
    property var services: [] // array of { id, title, url }
    property var disabledServices: ({})
    // Number of services visible in the current workspace (for empty state logic)
    property int filteredCount: 0
    // Profile provided by Main.qml (persistent)
    property WebEngineProfile webProfile

    function isDisabled(id) {
        return disabledServices && disabledServices.hasOwnProperty(id);
    }

    // currentIndex: 0 = empty state, 1..n = services
    // Use filteredCount to drive empty state when no services in current workspace
    currentIndex: filteredCount > 0 ? 1 : 0

    function setCurrentByServiceId(serviceId) {
        var idx = -1;
        for (var i = 0; i < services.length; i++) {
            if (services[i].id === serviceId) {
                idx = i;
                break;
            }
        }
        root.currentIndex = idx >= 0 ? (idx + 1) : 0;
    }

    function refreshCurrent() {
        if (root.currentIndex > 0 && root.currentIndex < root.children.length) {
            var wv = root.children[root.currentIndex];
            if (wv && wv.reload)
                wv.reload();
        }
    }

    function getWebViewByServiceId(serviceId) {
        for (var i = 0; i < services.length; i++) {
            if (services[i].id === serviceId) {
                var childIndex = i + 1;
                if (childIndex < root.children.length)
                    return root.children[childIndex].contents;
            }
        }
        return null;
    }

    // Empty state when no services
    Item {
        // Show empty state when current workspace has no services
        visible: filteredCount === 0
        Components.EmptyState {
            anchors.centerIn: parent
            width: parent.width
            text: i18n("No services in workspace")
            explanation: i18n("Add your first web service to get started")
        }
    }

    // A WebView for each service
    Repeater {
        model: root.services

        Components.ServiceWebView {
            serviceTitle: modelData.title
            serviceId: modelData.id
            initialUrl: root.isDisabled(modelData.id) ? "about:blank" : modelData.url
            webProfile: root.webProfile
            isServiceDisabled: root.isDisabled(modelData.id)
        }
    }
}
