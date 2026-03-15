import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection
import "Services.js" as Services

Item {
    id: view

    property string serviceTitle: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"
    property url configuredUrl: "about:blank"
    property WebEngineProfile webProfile
    property bool isServiceDisabled: false
    property var onTitleUpdated: null
    property int stackIndex: 0
    property real zoomFactor: 1.0
    property bool isMuted: false
    property bool globalMute: false
    property var restoredTabs: []

    property alias contents: view
    property int currentTabIndex: 0
    property var tabs: []
    property var tabViews: ({})

    readonly property bool isPlayingAudio: {
        for (var tabId in tabViews) {
            if (tabViews[tabId] && tabViews[tabId].recentlyAudible) {
                return true;
            }
        }
        return false;
    }

    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""

    signal audioStateChanged(string serviceId, bool isPlaying)
    signal mediaMetadataChanged(string serviceId, var metadata)
    signal updateServiceUrlRequested(string serviceId, string newUrl)
    signal fullscreenRequested(var webEngineView, bool toggleOn)
    signal zoomFactorUpdated(string serviceId, real zoomFactor)
    signal serviceTabsUpdated(string serviceId, var tabs)

    property bool profileReady: webProfile !== null
    property bool hasLoadedOnce: false

    onZoomFactorChanged: {
        for (var tabId in tabViews) {
            if (tabViews.hasOwnProperty(tabId) && tabViews[tabId]) {
                if (Math.abs(tabViews[tabId].zoomFactor - view.zoomFactor) > 0.001) {
                    tabViews[tabId].zoomFactor = view.zoomFactor;
                }
            }
        }
        view.zoomFactorUpdated(view.serviceId, view.zoomFactor);
    }

    onProfileReadyChanged: {
        if (profileReady && !isServiceDisabled) {
            initializeTabs();
        }
    }

    onRestoredTabsChanged: {
        if (profileReady && !isServiceDisabled && restoredTabs.length > 0) {
            initializeTabs();
        }
    }

    function generateTabId() {
        return "tab_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
    }

    function initializeTabs() {
        if (tabs.length > 0) {
            return;
        }

        if (restoredTabs && restoredTabs.length > 0) {
            for (var i = 0; i < restoredTabs.length; i++) {
                var tab = restoredTabs[i];
                createTab(tab.url, tab.title, i === 0);
            }
        } else if (initialUrl.toString() !== "about:blank") {
            createTab(initialUrl, serviceTitle, true);
        }
    }

    function createTab(url, title, isActive) {
        var tabId = generateTabId();
        var newTab = {
            id: tabId,
            url: url.toString(),
            title: title || i18n("Loading..."),
            isActive: isActive
        };

        var newTabs = tabs.slice();
        if (isActive) {
            for (var i = 0; i < newTabs.length; i++) {
                newTabs[i].isActive = false;
            }
            currentTabIndex = newTabs.length;
        }
        newTabs.push(newTab);
        tabs = newTabs;

        createWebViewForTab(tabId, url);

        if (isActive) {
            showTab(tabId);
        }

        saveTabs();
        return tabId;
    }

    function createWebViewForTab(tabId, url) {
        var component = Qt.createComponent("TabWebView.qml");
        if (component.status !== Component.Ready) {
            console.error("Failed to create TabWebView component:", component.errorString());
            return null;
        }

        var tabView = component.createObject(tabContainer, {
            "tabId": tabId,
            "serviceId": view.serviceId,
            "initialUrl": url,
            "webProfile": view.webProfile,
            "isMuted": view.isMuted,
            "globalMute": view.globalMute,
            "visible": false
        });

        if (!tabView) {
            console.error("Failed to create TabWebView instance");
            return null;
        }

        // Set zoom after creation (zoomFactor is a FINAL property)
        tabView.zoomFactor = view.zoomFactor;

        tabView.tabTitleChanged.connect(function(title) {
            updateTabTitle(tabId, title);
        });

        tabView.audioStateChanged.connect(function(svcId, isPlaying) {
            checkAudioState();
        });

        tabView.fullscreenRequested.connect(function(webEngineView, toggleOn) {
            view.fullscreenRequested(webEngineView, toggleOn);
        });

        tabView.newTabRequested.connect(function(url) {
            var newTabId = createTab(url, "", false);
            showTab(newTabId);
        });

        tabView.zoomUpdated.connect(function(zoomFactor) {
            if (Math.abs(view.zoomFactor - zoomFactor) > 0.001) {
                view.zoomFactor = zoomFactor;
            }
        });

        var newTabViews = Object.assign({}, tabViews);
        newTabViews[tabId] = tabView;
        tabViews = newTabViews;

        return tabView;
    }

    function updateTabTitle(tabId, title) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === tabId) {
                var newTabs = tabs.slice();
                newTabs[i].title = title;
                tabs = newTabs;
                saveTabs();
                break;
            }
        }

        if (tabs[currentTabIndex] && tabs[currentTabIndex].id === tabId) {
            if (view.onTitleUpdated && typeof view.onTitleUpdated === "function") {
                view.onTitleUpdated(view.serviceId, title);
            }
        }
    }

    function showTab(tabId) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === tabId) {
                var newTabs = tabs.slice();
                for (var j = 0; j < newTabs.length; j++) {
                    newTabs[j].isActive = (j === i);
                }
                tabs = newTabs;
                currentTabIndex = i;
                break;
            }
        }

        for (var id in tabViews) {
            if (tabViews.hasOwnProperty(id)) {
                tabViews[id].visible = (id === tabId);
            }
        }

        if (tabViews[tabId]) {
            view.hasLoadedOnce = true;
        }
    }

    function closeTab(tabId) {
        if (tabs.length <= 1) {
            return;
        }

        var closedIndex = -1;
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === tabId) {
                closedIndex = i;
                break;
            }
        }

        if (closedIndex === -1 || closedIndex === 0) return;

        var wasActive = tabs[closedIndex].isActive;

        if (tabViews[tabId]) {
            tabViews[tabId].destroy();
            var newTabViews = Object.assign({}, tabViews);
            delete newTabViews[tabId];
            tabViews = newTabViews;
        }

        var newTabs = tabs.slice();
        newTabs.splice(closedIndex, 1);
        tabs = newTabs;

        if (wasActive && tabs.length > 0) {
            var newActiveIndex = Math.min(closedIndex, tabs.length - 1);
            showTab(tabs[newActiveIndex].id);
        }

        currentTabIndex = Math.min(currentTabIndex, tabs.length - 1);
        saveTabs();
    }

    function checkAudioState() {
        var isPlaying = false;
        for (var tabId in tabViews) {
            if (tabViews[tabId] && tabViews[tabId].recentlyAudible) {
                isPlaying = true;
                break;
            }
        }
        view.audioStateChanged(view.serviceId, isPlaying);
    }

    function saveTabs() {
        var tabsToSave = [];
        for (var i = 0; i < tabs.length; i++) {
            tabsToSave.push({
                url: tabs[i].url,
                title: tabs[i].title,
                isActive: tabs[i].isActive
            });
        }
        view.serviceTabsUpdated(view.serviceId, tabsToSave);
    }

    function getCurrentWebView() {
        if (tabs.length === 0 || currentTabIndex >= tabs.length) {
            return null;
        }
        var currentTab = tabs[currentTabIndex];
        return tabViews[currentTab.id] || null;
    }

    function printPage() {
        var currentWebView = getCurrentWebView();
        if (currentWebView && currentWebView.printPage) {
            currentWebView.printPage();
        }
    }

    function refreshCurrent() {
        var currentWebView = getCurrentWebView();
        if (currentWebView && currentWebView.reload) {
            currentWebView.reload();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ServiceTabBar {
            id: tabBar
            Layout.fillWidth: true
            tabs: view.tabs
            activeIndex: view.currentTabIndex
            onTabSelected: function(index) {
                if (index >= 0 && index < view.tabs.length) {
                    view.showTab(view.tabs[index].id);
                }
            }
            onTabClosed: function(index) {
                if (index >= 0 && index < view.tabs.length) {
                    view.closeTab(view.tabs[index].id);
                }
            }
            onOpenInServiceRequested: function(index) {
                if (index > 0 && index < view.tabs.length) {
                    var tab = view.tabs[index];
                    if (view.tabs.length > 0 && view.tabs[0]) {
                        var mainTabView = view.tabViews[view.tabs[0].id];
                        if (mainTabView) {
                            mainTabView.url = tab.url;
                        }
                    }
                    view.showTab(view.tabs[0].id);
                    view.closeTab(tab.id);
                }
            }
            onOpenInBrowserRequested: function(index) {
                if (index >= 0 && index < view.tabs.length) {
                    var tab = view.tabs[index];
                    Qt.openUrlExternally(tab.url);
                    view.closeTab(tab.id);
                }
            }
        }

        Item {
            id: tabContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: view.isServiceDisabled
                z: 1
                text: i18n("Service Disabled")
                explanation: i18n("This service is currently disabled. Enable it to use this web service.")
                icon.name: "offline"
            }

            Kirigami.LoadingPlaceholder {
                anchors.centerIn: parent
                visible: !view.isServiceDisabled && !view.hasLoadedOnce && view.tabs.length > 0
                text: i18n("Loading %1...", view.serviceTitle)
            }
        }
    }

    Component.onCompleted: {
        if (webProfile && !isServiceDisabled) {
            initializeTabs();
        }
    }
}