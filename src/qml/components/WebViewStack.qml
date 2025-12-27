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

    // Signal to propagate service URL update requests
    signal updateServiceUrlRequested(string serviceId, string newUrl)

    // Internal properties
    property string currentServiceId: ""
    property var webViewCache: ({}) // serviceId -> WebView component instance
    property var isolatedProfiles: ({}) // serviceId -> WebEngineProfile for isolated services
    property bool isInitialized: false

    // Track which services are currently playing audio
    property var audibleServices: ({})

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

    // Helper function to find the actual index of a child in the StackLayout
    function findChildIndex(item) {
        var children = stackLayout.children;
        for (var i = 0; i < children.length; i++) {
            if (children[i] === item) {
                return i;
            }
        }
        return -1;
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
            // Find the actual index in the StackLayout (may differ from stackIndex after reparenting)
            var actualIndex = findChildIndex(webViewCache[serviceId]);
            if (actualIndex >= 0) {
                stackLayout.currentIndex = actualIndex;
            } else {
                // Fallback to stored stackIndex if item not found (shouldn't happen)
                stackLayout.currentIndex = webViewCache[serviceId].stackIndex;
            }
        } else {
            // This shouldn't happen with pre-loading, but keep as fallback
            console.warn("Service not pre-loaded:", serviceId, "- creating now");
            createWebViewForService(serviceId);
            if (webViewCache[serviceId]) {
                var idx = findChildIndex(webViewCache[serviceId]);
                stackLayout.currentIndex = idx >= 0 ? idx : webViewCache[serviceId].stackIndex;
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

    function refreshByServiceId(serviceId) {
        if (webViewCache[serviceId]) {
            var wv = webViewCache[serviceId];
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

    // Get the ServiceWebView container (not just WebEngineView contents)
    function getServiceWebViewByServiceId(serviceId) {
        if (webViewCache[serviceId]) {
            return webViewCache[serviceId];
        }
        return null;
    }

    function getCurrentWebView() {
        if (currentServiceId && webViewCache[currentServiceId]) {
            return webViewCache[currentServiceId];
        }
        return null;
    }

    // Detach a ServiceWebView from the stack (for reparenting to external window)
    // Returns the ServiceWebView instance that was detached
    function detachWebView(serviceId) {
        if (!webViewCache[serviceId]) {
            console.warn("Cannot detach: WebView not found for service:", serviceId);
            return null;
        }

        var serviceWebView = webViewCache[serviceId];

        console.log("Detaching WebView for service:", serviceId, "from stack index:", serviceWebView.stackIndex);

        // Return the ServiceWebView - caller will reparent it
        return serviceWebView;
    }

    // Reattach a previously detached ServiceWebView back to the stack
    function reattachWebView(serviceId, serviceWebView) {
        if (!serviceWebView) {
            console.warn("Cannot reattach: ServiceWebView is null");
            return false;
        }

        // Clear any anchors set by the detached window before reparenting
        serviceWebView.anchors.fill = undefined;
        serviceWebView.anchors.top = undefined;
        serviceWebView.anchors.bottom = undefined;
        serviceWebView.anchors.left = undefined;
        serviceWebView.anchors.right = undefined;

        // Reparent back to the stack layout
        // StackLayout manages child sizes automatically, so we don't need anchors
        serviceWebView.parent = stackLayout;

        // Reset z to default (StackLayout manages visibility, not z-order)
        serviceWebView.z = 0;

        // StackLayout controls visibility of its children based on currentIndex
        // We need to explicitly set visible to false so StackLayout can manage it
        // The current view's visibility will be set to true by StackLayout
        serviceWebView.visible = false;

        // Force StackLayout to re-evaluate its layout by toggling currentIndex
        var currentIdx = stackLayout.currentIndex;
        stackLayout.currentIndex = -1;
        stackLayout.currentIndex = currentIdx;

        console.log("Reattached WebView for service:", serviceId, "- StackLayout refreshed");
        return true;
    }

    function getOrCreateIsolatedProfile(serviceId, userAgent) {
        // Check if we already have an isolated profile for this service
        if (isolatedProfiles[serviceId]) {
            console.log("Reusing existing isolated profile for:", serviceId);
            return isolatedProfiles[serviceId];
        }

        console.log("Creating NEW isolated profile for service:", serviceId);

        // Create a new isolated profile for this service
        // Note: storageName MUST be set at creation time and cannot be changed later
        var profile = isolatedProfileComponent.createObject(root, {
            "storageName": "unify-isolated-" + serviceId,
            "httpUserAgent": userAgent || ""
        });

        if (profile) {
            var profiles = root.isolatedProfiles;
            profiles[serviceId] = profile;
            root.isolatedProfiles = profiles;
            console.log("Created isolated profile for service:", serviceId,
                        "storageName:", profile.storageName,
                        "offTheRecord:", profile.offTheRecord);
        } else {
            console.error("Failed to create isolated profile component for:", serviceId);
        }

        return profile;
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

        // Determine which profile to use: isolated or shared
        var profileToUse = root.webProfile;
        if (serviceData.isolatedProfile) {
            // Pass the user agent from the shared profile to maintain consistency
            var userAgent = root.webProfile ? root.webProfile.httpUserAgent : "";
            profileToUse = getOrCreateIsolatedProfile(serviceData.id, userAgent);
            if (!profileToUse) {
                console.error("Failed to create isolated profile for service:", serviceId);
                profileToUse = root.webProfile; // Fallback to shared profile
            }
        }

        var instance = component.createObject(stackLayout, {
            "serviceTitle": serviceData.title,
            "serviceId": serviceData.id,
            "initialUrl": initialUrl,
            "configuredUrl": serviceData.url,
            "webProfile": profileToUse,
            "isServiceDisabled": root.isDisabled(serviceData.id),
            "onTitleUpdated": root.onTitleUpdated,
            "stackIndex": nextIndex
        });

        if (!instance) {
            console.error("Failed to create ServiceWebView instance");
            return;
        }

        // Connect the updateServiceUrlRequested signal
        instance.updateServiceUrlRequested.connect(function (svcId, newUrl) {
            root.updateServiceUrlRequested(svcId, newUrl);
        });

        // Monitor audio playback state changes
        instance.audioStateChanged.connect(function (svcId, isPlaying) {
            // Create a new object to ensure QML property change is detected
            var audible = Object.assign({}, root.audibleServices);
            if (isPlaying) {
                audible[svcId] = true;
            } else {
                delete audible[svcId];
            }
            root.audibleServices = audible;
            console.log("🔊 Updated audibleServices:", JSON.stringify(root.audibleServices));
        });

        // Store in cache
        var cache = root.webViewCache;
        cache[serviceId] = instance;
        root.webViewCache = cache;

        console.log("Created WebView for service:", serviceId, "at index:", nextIndex, serviceData.isolatedProfile ? "(isolated)" : "(shared)");
    }

    function updateWebViewForService(serviceId, serviceData) {
        var view = webViewCache[serviceId];
        if (!view) {
            return;
        }

        // Ensure serviceData has required properties
        if (!serviceData || !serviceData.url) {
            console.warn("Invalid serviceData for:", serviceId);
            return;
        }

        // Update properties
        view.serviceTitle = serviceData.title;
        view.isServiceDisabled = root.isDisabled(serviceData.id);

        // Only reload the WebView if the configured URL changed
        var newUrl = root.isDisabled(serviceData.id) ? "about:blank" : serviceData.url;
        var currentConfiguredUrl = view.configuredUrl ? view.configuredUrl.toString() : "";
        if (currentConfiguredUrl !== serviceData.url) {
            view.configuredUrl = serviceData.url;
            if (view.contents) {
                view.contents.url = newUrl;
                console.log("URL changed for service:", serviceId, "reloading to:", newUrl);
            }
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

        // Also destroy isolated profile if it exists
        if (isolatedProfiles[serviceId]) {
            isolatedProfiles[serviceId].destroy();
            var profiles = root.isolatedProfiles;
            delete profiles[serviceId];
            root.isolatedProfiles = profiles;
            console.log("Destroyed isolated profile for service:", serviceId);
        }

        // Remove from audible services if present
        if (audibleServices[serviceId]) {
            var audible = Object.assign({}, root.audibleServices);
            delete audible[serviceId];
            root.audibleServices = audible;
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

    // Component for creating isolated WebEngine profiles dynamically
    Component {
        id: isolatedProfileComponent

        WebEngineProfile {
            // storageName and httpUserAgent will be set when creating the object
            offTheRecord: false
            httpCacheType: WebEngineProfile.DiskHttpCache
            persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        }
    }
}
