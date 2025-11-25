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

    // Update all webviews when disabledServices changes
    onDisabledServicesChanged: {
        for (var serviceId in webViewCache) {
            if (webViewCache.hasOwnProperty(serviceId)) {
                var view = webViewCache[serviceId];
                if (view) {
                    view.isServiceDisabled = isDisabled(serviceId);
                }
            }
        }
    }

    function setCurrentByServiceId(serviceId) {
        root.currentServiceId = serviceId;

        // Show empty state if no services in workspace
        if (filteredCount === 0) {
            stackLayout.currentIndex = 0;
            return;
        }

        // Switch to the view (should already exist)
        if (webViewCache[serviceId]) {
            stackLayout.currentIndex = webViewCache[serviceId].stackIndex;
        } else {
            // Fallback: create if doesn't exist
            createWebViewForService(serviceId);
            if (webViewCache[serviceId]) {
                stackLayout.currentIndex = webViewCache[serviceId].stackIndex;
            } else {
                stackLayout.currentIndex = 0;
            }
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

    function updateWebViewForService(serviceId, serviceData) {
        var view = webViewCache[serviceId];
        if (!view) {
            return;
        }

        // Update properties
        view.serviceTitle = serviceData.title;
        view.isServiceDisabled = root.isDisabled(serviceData.id);

        // If URL changed, reload the WebView
        var newUrl = root.isDisabled(serviceData.id) ? "about:blank" : serviceData.url;
        if (view.contents && view.contents.url.toString() !== newUrl) {
            view.contents.url = newUrl;
            console.log("URL changed for service:", serviceId, "reloading to:", newUrl);
        }
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
        var currentServiceIds = [];

        // Create or update views for all services
        for (var i = 0; i < services.length; i++) {
            var svc = services[i];
            currentServiceIds.push(svc.id);

            if (!webViewCache[svc.id]) {
                // Create new view
                createWebViewForService(svc.id);
            } else {
                // Update existing view properties
                updateWebViewForService(svc.id, svc);
            }
        }

        // Destroy views for removed services
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
