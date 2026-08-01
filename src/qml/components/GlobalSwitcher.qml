import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Floating service switcher: fuzzy-filter the full service list and jump to
// a service quickly (opened with Ctrl+K from Main.qml).
Controls.Popup {
    id: root

    // Full list of services across all workspaces (from configManager)
    property var services: []
    // Currently active service (shown highlighted in the list)
    property string currentServiceId: ""

    signal serviceSelected(string id)

    modal: true
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Kirigami.Units.gridUnit * 26
    padding: Kirigami.Units.smallSpacing

    // Filtered model backing the ListView
    property var filtered: []

    function refilter() {
        var query = searchField.text.trim().toLowerCase();
        var result = [];
        for (var i = 0; i < services.length; i++) {
            var service = services[i];
            if (!service || !service.id)
                continue;
            if (query === ""
                || (service.title && service.title.toLowerCase().indexOf(query) !== -1)
                || (service.workspace && service.workspace.toLowerCase().indexOf(query) !== -1)) {
                result.push(service);
            }
        }
        filtered = result;
        listView.currentIndex = filtered.length > 0 ? 0 : -1;
    }

    function selectCurrent() {
        if (listView.currentIndex >= 0 && listView.currentIndex < filtered.length) {
            root.serviceSelected(filtered[listView.currentIndex].id);
            root.close();
        }
    }

    onOpened: {
        searchField.text = "";
        refilter();
        searchField.forceActiveFocus();
    }

    onServicesChanged: refilter()

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: searchField

            Layout.fillWidth: true
            placeholderText: i18n("Search services...")
            leftPadding: Kirigami.Units.gridUnit * 1.5

            Kirigami.Icon {
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "search"
            }

            onTextChanged: root.refilter()

            Keys.onDownPressed: {
                if (listView.currentIndex < root.filtered.length - 1)
                    listView.currentIndex++;
            }
            Keys.onUpPressed: {
                if (listView.currentIndex > 0)
                    listView.currentIndex--;
            }
            Keys.onReturnPressed: root.selectCurrent()
            Keys.onEnterPressed: root.selectCurrent()
        }

        ListView {
            id: listView

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 20)
            clip: true
            model: root.filtered
            keyNavigationEnabled: false
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0

            highlight: Rectangle {
                color: Kirigami.Theme.highlightColor
                radius: Kirigami.Units.smallSpacing
            }

            delegate: Controls.ItemDelegate {
                id: delegateItem

                width: listView.width
                height: Kirigami.Units.gridUnit * 2.5
                // Zero the style's default padding so the content is vertically
                // centered instead of being pushed down inside the item.
                padding: 0
                horizontalPadding: Kirigami.Units.smallSpacing
                highlighted: ListView.isCurrentItem
                onClicked: {
                    root.serviceSelected(modelData.id);
                    root.close();
                }

                background: Item {}

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    // Service icon — mirrors the cache/request logic from
                    // ServiceIconButton so favicons resolve asynchronously.
                    Item {
                        id: iconContainer

                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium

                        property string serviceUrl: modelData.url || ""
                        property string image: modelData.image || ""
                        property bool useFavicon: modelData.useFavicon || false
                        property string cachedFaviconUrl: ""
                        property string cachedImageUrl: ""

                        readonly property bool isUrl: image.match(/^https?:\/\//) !== null
                        readonly property bool hasImage: image.trim() !== ""
                        readonly property bool shouldShowFavicon: useFavicon && cachedFaviconUrl !== ""
                        readonly property bool shouldShowImage: !useFavicon && hasImage && isUrl && cachedImageUrl !== ""
                        readonly property bool shouldShowIcon: !useFavicon && hasImage && !isUrl

                        function requestCachedAssets() {
                            if (typeof faviconCache === "undefined" || faviconCache === null)
                                return;

                            if (useFavicon && serviceUrl !== "") {
                                var cached = faviconCache.getFavicon(serviceUrl, true);
                                if (cached && cached !== "")
                                    cachedFaviconUrl = cached;
                            } else if (!useFavicon && hasImage && isUrl) {
                                var cachedImg = faviconCache.getImageUrl(image);
                                if (cachedImg && cachedImg !== "")
                                    cachedImageUrl = cachedImg;
                            }
                        }

                        Component.onCompleted: requestCachedAssets()

                        Connections {
                            target: typeof faviconCache !== "undefined" ? faviconCache : null

                            function onFaviconReady(serviceUrl, localPath) {
                                if (iconContainer.useFavicon && iconContainer.serviceUrl === serviceUrl)
                                    iconContainer.cachedFaviconUrl = localPath;
                            }

                            function onImageReady(imageUrl, localPath) {
                                if (!iconContainer.useFavicon && iconContainer.image === imageUrl)
                                    iconContainer.cachedImageUrl = localPath;
                            }
                        }

                        Image {
                            anchors.fill: parent
                            visible: iconContainer.shouldShowFavicon || iconContainer.shouldShowImage
                            source: iconContainer.shouldShowFavicon ? iconContainer.cachedFaviconUrl : iconContainer.cachedImageUrl
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Kirigami.Icon {
                            anchors.fill: parent
                            visible: !iconContainer.shouldShowFavicon && !iconContainer.shouldShowImage
                            source: iconContainer.shouldShowIcon ? iconContainer.image : "internet-web-browser-symbolic"
                            fallback: "internet-web-browser-symbolic"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            elide: Controls.Label.ElideRight
                            color: delegateItem.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: modelData.workspace || ""
                            elide: Controls.Label.ElideRight
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            color: delegateItem.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: root.filtered.length === 0
            text: i18n("No services found")
            horizontalAlignment: Controls.Label.AlignHCenter
            opacity: 0.6
            bottomPadding: Kirigami.Units.smallSpacing
        }
    }
}
