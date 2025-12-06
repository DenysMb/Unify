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
    // Current workspace name (for customizing empty state message)
    property string currentWorkspace: ""
    // Profile provided by Main.qml (persistent)
    property WebEngineProfile webProfile
    // Callback to update badge from title
    property var onTitleUpdated: null

    // Internal properties
    property string currentServiceId: ""
    property var webViewCache: ({}) // serviceId -> WebView component instance
    property bool isInitialized: false

    // Expose currentIndex property to allow external control
    property alias currentIndex: stackLayout.currentIndex

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

        // Show empty state if no services in workspace or serviceId is empty
        if (filteredCount === 0 || !serviceId || serviceId === "") {
            stackLayout.currentIndex = 0;
            return;
        }

        // Switch to the view (all services are pre-loaded, so it should always exist)
        if (webViewCache[serviceId]) {
            stackLayout.currentIndex = webViewCache[serviceId].stackIndex;
        } else {
            // This shouldn't happen with pre-loading, but keep as fallback
            console.warn("Service not pre-loaded:", serviceId, "- creating now");
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
        // Don't create if profile is not ready
        if (!root.webProfile) {
            console.warn("WebProfile not ready, delaying service creation:", serviceId);
            return;
        }

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

        // Create the instance with delayed URL loading for disabled services
        var initialUrl = root.isDisabled(serviceData.id) ? "about:blank" : serviceData.url;

        var instance = component.createObject(stackLayout, {
            "serviceTitle": serviceData.title,
            "serviceId": serviceData.id,
            "initialUrl": initialUrl,
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
        // Don't process if profile is not ready or services is empty/null
        if (!root.webProfile || !services || services.length === 0) {
            return;
        }

        var currentServiceIds = [];

        // PRE-LOAD: Create or update views for ALL services immediately
        // This ensures instant switching between services with no loading delay
        for (var i = 0; i < services.length; i++) {
            var svc = services[i];
            currentServiceIds.push(svc.id);

            if (!webViewCache[svc.id]) {
                // Create new view (will load immediately)
                console.log("Pre-loading service:", svc.title);
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

        root.isInitialized = true;
    }

    // Monitor webProfile changes to initialize services when profile becomes available
    onWebProfileChanged: {
        if (root.webProfile && services && services.length > 0 && !root.isInitialized) {
            console.log("WebProfile now available, initializing services...");
            // Trigger services reload
            var svcCopy = services;
            services = [];
            services = svcCopy;
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
                iconName: root.currentWorkspace === "__favorites__" ? "favorite" : ""
                text: root.currentWorkspace === "__favorites__" ? i18n("No favorite services yet") : i18n("No services in workspace")
                explanation: root.currentWorkspace === "__favorites__" ? i18n("Right-click on any service and select 'Add to Favorites' to see it here") : i18n("Add your first web service to get started")
            }
        }

        // WebViews will be dynamically added here by createWebViewForService
    }
}
