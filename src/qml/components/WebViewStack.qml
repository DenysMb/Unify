import QtQuick
import QtQuick.Layouts
import QtWebEngine

import "./" as Components
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Public API
    property var services: [] // array of { id, title, url }
    property var disabledServices: ({})
    // Number of services visible in the current workspace (for empty state logic)
    property int filteredCount: 0
    // Profile provided by Main.qml (persistent)
    property WebEngineProfile webProfile
    // Callback to update badge from title
    property var onTitleUpdated: null

    // Internal properties
    property string currentServiceId: ""
    property var webViewCache: ({}) // serviceId -> WebView component instance

    function isDisabled(id) {
        return disabledServices && disabledServices.hasOwnProperty(id);
    }

    function setCurrentByServiceId(serviceId) {
        root.currentServiceId = serviceId;

        // Show empty state if no services in workspace
        if (filteredCount === 0) {
            stackLayout.currentIndex = 0;
            return;
        }

        // Ensure view exists for this service
        if (!webViewCache[serviceId]) {
            createWebViewForService(serviceId);
        }

        // Switch to the view
        if (webViewCache[serviceId]) {
            stackLayout.currentIndex = webViewCache[serviceId].stackIndex;
        } else {
            stackLayout.currentIndex = 0;
        }
    }

    function refreshCurrent() {
        if (webViewCache[currentServiceId]) {
            var wv = webViewCache[currentServiceId];
            if (wv.contents && wv.contents.reload) {
                wv.contents.reload();
            }
        }
    }

    function getWebViewByServiceId(serviceId) {
        if (webViewCache[serviceId]) {
            return webViewCache[serviceId].contents;
        }
        return null;
    }

    function createWebViewForService(serviceId) {
        // Find service data
        var serviceData = null;
        for (var i = 0; i < services.length; i++) {
            if (services[i].id === serviceId) {
                serviceData = services[i];
                break;
            }
        }

        if (!serviceData) {
            console.warn("Cannot create WebView for unknown service:", serviceId);
            return;
        }

        // Don't recreate if already exists
        if (webViewCache[serviceId]) {
            return;
        }

        // Create the component
        var component = Qt.createComponent("ServiceWebView.qml");
        if (component.status !== Component.Ready) {
            console.error("Error loading ServiceWebView component:", component.errorString());
            return;
        }

        // Calculate next stack index (empty state is 0, views start at 1)
        var nextIndex = Object.keys(webViewCache).length + 1;

        // Create the instance
        var instance = component.createObject(stackLayout, {
            "serviceTitle": serviceData.title,
            "serviceId": serviceData.id,
            "initialUrl": root.isDisabled(serviceData.id) ? "about:blank" : serviceData.url,
            "webProfile": root.webProfile,
            "isServiceDisabled": root.isDisabled(serviceData.id),
            "onTitleUpdated": root.onTitleUpdated,
            "stackIndex": nextIndex
        });

        if (!instance) {
            console.error("Failed to create ServiceWebView instance");
            return;
        }

        // Store in cache
        var cache = root.webViewCache;
        cache[serviceId] = instance;
        root.webViewCache = cache;

        console.log("Created WebView for service:", serviceId, "at index:", nextIndex);
    }

    function destroyWebViewForService(serviceId) {
        if (webViewCache[serviceId]) {
            webViewCache[serviceId].destroy();
            var cache = root.webViewCache;
            delete cache[serviceId];
            root.webViewCache = cache;
            console.log("Destroyed WebView for service:", serviceId);
        }
    }

    // Sync views when services list changes
    onServicesChanged: {
        // Create views for new services
        for (var i = 0; i < services.length; i++) {
            var svc = services[i];
            if (!webViewCache[svc.id])
            // Don't create immediately - wait until user switches to it
            // This is lazy loading to improve performance
            {}
        }

        // Destroy views for removed services
        var currentServiceIds = [];
        for (var j = 0; j < services.length; j++) {
            currentServiceIds.push(services[j].id);
        }

        var cachedIds = Object.keys(webViewCache);
        for (var k = 0; k < cachedIds.length; k++) {
            var cachedId = cachedIds[k];
            if (currentServiceIds.indexOf(cachedId) === -1) {
                destroyWebViewForService(cachedId);
            }
        }
    }

    StackLayout {
        id: stackLayout
        anchors.fill: parent
        currentIndex: filteredCount > 0 ? 1 : 0

        // Empty state when no services
        Item {
            Components.EmptyState {
                anchors.centerIn: parent
                width: parent.width
                text: i18n("No services in workspace")
                explanation: i18n("Add your first web service to get started")
            }
        }

        // WebViews will be dynamically added here by createWebViewForService
    }
}
