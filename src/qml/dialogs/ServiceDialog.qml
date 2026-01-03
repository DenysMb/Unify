import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property var workspaces: []
    property string currentWorkspace: ""
    property var serviceData: ({
            title: "",
            url: "",
            image: "",
            workspace: "",
            useFavicon: false,
            isolatedProfile: false
        })

    signal acceptedData(var data)
    signal deleteRequested

    property string selectedIconName: "internet-web-browser-symbolic"
    property bool useFavicon: true
    property bool isolatedProfile: false
    property int selectedFaviconSource: 0 // 0 = Google, 1 = IconHorse

    // Favicon preview URLs
    property string googleFaviconUrl: ""
    property string iconHorseFaviconUrl: ""
    property bool googleFaviconLoading: false
    property bool iconHorseFaviconLoading: false

    // Validation properties
    readonly property bool isNameValid: serviceNameField.text.trim().length > 0
    readonly property bool isUrlValid: {
        var url = serviceUrlField.text.trim();
        if (url.length === 0)
            return false;
        // Accept http://, https://, or domain-only
        var urlPattern = /^(https?:\/\/)|([\w-]+\.[\w-]+)/;
        return urlPattern.test(url);
    }
    readonly property bool isFormValid: isNameValid && isUrlValid
    readonly property bool isUsingHttp: serviceUrlField.text.trim().startsWith("http://")

    title: isEditMode ? i18n("Edit Service") : i18n("Add Service")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    // Disable OK button when form is invalid
    Component.onCompleted: {
        standardButton(Kirigami.Dialog.Ok).enabled = Qt.binding(function () {
            return root.isFormValid;
        });
    }

    function populateFields(service) {
        serviceNameField.text = service.title || "";
        iconUrlField.text = service.image || "";
        serviceUrlField.text = service.url || "";

        // Filter out special workspaces when finding the index
        var filteredWorkspaces = [];
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i] !== "__favorites__" && workspaces[i] !== "__all_services__") {
                filteredWorkspaces.push(workspaces[i]);
            }
        }
        workspaceComboBox.currentIndex = Math.max(0, filteredWorkspaces.indexOf(service.workspace || filteredWorkspaces[0]));
        root.selectedIconName = service.image || "internet-web-browser-symbolic";
        root.useFavicon = service.useFavicon || false;
        root.isolatedProfile = service.isolatedProfile || false;
        root.selectedFaviconSource = service.faviconSource || 0;

        // Fetch favicon previews if URL is valid
        if (service.url) {
            fetchFaviconPreviews();
        }
    }

    function clearFields() {
        serviceNameField.text = "";
        iconUrlField.text = "";
        serviceUrlField.text = "";
        root.googleFaviconUrl = "";
        root.iconHorseFaviconUrl = "";
        root.googleFaviconLoading = false;
        root.iconHorseFaviconLoading = false;
        root.selectedFaviconSource = 0;
        // Set to current workspace if available, otherwise default to first
        // Filter out special workspaces
        var filteredWorkspaces = [];
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i] !== "__favorites__" && workspaces[i] !== "__all_services__") {
                filteredWorkspaces.push(workspaces[i]);
            }
        }
        var wsIndex = root.currentWorkspace ? Math.max(0, filteredWorkspaces.indexOf(root.currentWorkspace)) : 0;
        workspaceComboBox.currentIndex = wsIndex;
        root.selectedIconName = "internet-web-browser-symbolic";
        root.useFavicon = true;
        root.isolatedProfile = false;
    }

    function fetchFaviconPreviews() {
        if (!serviceUrlField.text || !root.isUrlValid) {
            return;
        }

        var url = serviceUrlField.text.trim();
        // Prepend https:// if no protocol is specified (for favicon fetching)
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "https://" + url;
        }

        // Fetch Google favicon
        root.googleFaviconLoading = true;
        if (typeof faviconCache !== "undefined" && faviconCache !== null) {
            faviconCache.fetchFaviconFromSource(url, 0); // 0 = GoogleSource

            // Try to get from cache immediately
            var googleCached = faviconCache.getFaviconForSource(url, 0);
            if (googleCached && googleCached !== "") {
                root.googleFaviconUrl = googleCached;
                root.googleFaviconLoading = false;
            }

            // Fetch IconHorse favicon
            root.iconHorseFaviconLoading = true;
            faviconCache.fetchFaviconFromSource(url, 1); // 1 = IconHorseSource

            // Try to get from cache immediately
            var iconHorseCached = faviconCache.getFaviconForSource(url, 1);
            if (iconHorseCached && iconHorseCached !== "") {
                root.iconHorseFaviconUrl = iconHorseCached;
                root.iconHorseFaviconLoading = false;
            }
        }
    }

    function clearFaviconPreviews() {
        root.googleFaviconUrl = "";
        root.iconHorseFaviconUrl = "";
        root.googleFaviconLoading = false;
        root.iconHorseFaviconLoading = false;
    }

    onAccepted: {
        // Filter out special workspaces to get the correct workspace from ComboBox
        var filteredWorkspaces = [];
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i] !== "__favorites__" && workspaces[i] !== "__all_services__") {
                filteredWorkspaces.push(workspaces[i]);
            }
        }

        var url = serviceUrlField.text.trim();
        // Auto-prepend https:// ONLY if no protocol is specified (domain-only)
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "https://" + url;
        }

        var data = {
            title: serviceNameField.text,
            url: url,
            image: iconUrlField.text.trim() || "internet-web-browser-symbolic",
            workspace: filteredWorkspaces[workspaceComboBox.currentIndex],
            useFavicon: root.useFavicon,
            isolatedProfile: root.isolatedProfile,
            faviconSource: root.useFavicon ? root.selectedFaviconSource : -1
        };
        acceptedData(data);
        clearFields();
    }
    onRejected: {
        clearFields();
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: serviceNameField
            Kirigami.FormData.label: i18n("Service Name:")
            placeholderText: i18n("Enter service name")
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: serviceUrlField
            Kirigami.FormData.label: i18n("Service URL:")
            placeholderText: i18n("Enter service URL")
            Layout.fillWidth: true

            onTextChanged: {
                // Restart the favicon fetch timer when URL changes
                faviconFetchTimer.restart();
            }

            Controls.ToolTip.visible: text.trim().length > 0 && !root.isUrlValid && hovered
            Controls.ToolTip.text: i18n("URL must start with http://, https://, or be a valid domain (e.g., example.com)")
        }

        // HTTP security warning
        Controls.Label {
            text: i18n("⚠️ Using HTTP is not secure. Your connection will not be encrypted.")
            visible: root.isUsingHttp
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Controls.Label {
            text: i18n("For security, we recommend using HTTPS.")
            visible: root.isUsingHttp
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Controls.CheckBox {
            id: useFaviconCheckbox
            Kirigami.FormData.label: ""
            text: i18n("Use service favicon in sidebar")
            checked: root.useFavicon
            onCheckedChanged: {
                root.useFavicon = checked;
                if (checked) {
                    fetchFaviconPreviews();
                } else {
                    clearFaviconPreviews();
                }
            }
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("When enabled, the service's favicon will be displayed in the sidebar instead of the selected icon")
        }

        // Favicon source selection (shown when useFavicon is enabled)
        Column {
            visible: useFaviconCheckbox.checked
            Kirigami.FormData.label: ""
            Kirigami.FormData.isSection: false
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Row {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                // Google favicon preview
                Rectangle {
                    width: Kirigami.Units.gridUnit * 6
                    height: Kirigami.Units.gridUnit * 6
                    color: root.selectedFaviconSource === 0 ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                    border.width: root.selectedFaviconSource === 0 ? 2 : 1
                    border.color: root.selectedFaviconSource === 0 ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
                    radius: Kirigami.Units.smallSpacing

                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                    Item {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height)
                            height: Math.min(parent.width, parent.height)
                            source: root.googleFaviconUrl
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: root.googleFaviconUrl !== ""
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium
                            height: Kirigami.Units.iconSizes.medium
                            source: "internet-web-browser-symbolic"
                            visible: root.googleFaviconLoading && root.googleFaviconUrl === ""
                            opacity: 0.5
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small
                            source: "edit-none"
                            visible: !root.googleFaviconLoading && root.googleFaviconUrl === ""
                            opacity: 0.5
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedFaviconSource = 0
                        cursorShape: Qt.PointingHandCursor
                    }

                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: i18n("Click to use Google favicon\n\nGoogle favicon service with automatic fallback to root domain")
                }

                // IconHorse favicon preview
                Rectangle {
                    width: Kirigami.Units.gridUnit * 6
                    height: Kirigami.Units.gridUnit * 6
                    color: root.selectedFaviconSource === 1 ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                    border.width: root.selectedFaviconSource === 1 ? 2 : 1
                    border.color: root.selectedFaviconSource === 1 ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
                    radius: Kirigami.Units.smallSpacing

                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                    Item {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height)
                            height: Math.min(parent.width, parent.height)
                            source: root.iconHorseFaviconUrl
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: root.iconHorseFaviconUrl !== ""
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium
                            height: Kirigami.Units.iconSizes.medium
                            source: "internet-web-browser-symbolic"
                            visible: root.iconHorseFaviconLoading && root.iconHorseFaviconUrl === ""
                            opacity: 0.5
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small
                            source: "edit-none"
                            visible: !root.iconHorseFaviconLoading && root.iconHorseFaviconUrl === ""
                            opacity: 0.5
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedFaviconSource = 1
                        cursorShape: Qt.PointingHandCursor
                    }

                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: i18n("Click to use IconHorse favicon\n\nAlternative favicon service that may have icons not available on Google")
                }
            }

            // Label showing the current selection
            Controls.Label {
                text: root.selectedFaviconSource === 0 ? i18n("Selected: Google") : i18n("Selected: IconHorse")
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                opacity: 0.7
            }
        }

        Controls.TextField {
            id: iconUrlField
            Kirigami.FormData.label: i18n("Icon URL:")
            placeholderText: i18n("Enter icon URL")
            Layout.fillWidth: true
            enabled: !useFaviconCheckbox.checked
        }

        Controls.Button {
            id: iconButton
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            readonly property bool hasCustomIcon: {
                var text = iconUrlField.text.trim();
                return text && !(text.startsWith("http://") || text.startsWith("https://") || text.startsWith("file://") || text.startsWith("qrc:/"));
            }

            text: hasCustomIcon ? "" : i18n("Or select a custom icon")
            icon.name: hasCustomIcon ? (iconUrlField.text.trim() || root.selectedIconName) : ""
            display: hasCustomIcon ? Controls.AbstractButton.IconOnly : Controls.AbstractButton.TextOnly

            onClicked: iconDialog.open()
            enabled: !useFaviconCheckbox.checked

            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Choose icon from system")
        }

        Controls.ComboBox {
            id: workspaceComboBox
            Kirigami.FormData.label: i18n("Workspace:")
            model: {
                // Filter out special workspaces
                var filtered = [];
                for (var i = 0; i < root.workspaces.length; i++) {
                    var ws = root.workspaces[i];
                    if (ws !== "__favorites__" && ws !== "__all_services__") {
                        filtered.push(ws);
                    }
                }
                return filtered;
            }
            Layout.fillWidth: true
        }

        Controls.CheckBox {
            id: isolatedProfileCheckbox
            Kirigami.FormData.label: ""
            text: i18n("Use isolated storage")
            checked: root.isolatedProfile
            onCheckedChanged: root.isolatedProfile = checked
            enabled: !root.isEditMode
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: root.isEditMode ? i18n("This option cannot be changed after the service is created. Delete and recreate the service if you need to change this setting.") : i18n("When enabled, this service will have its own separate cookies, login sessions, and data. Useful for having multiple accounts of the same service.")
        }

        // Separator before destructive actions (only in edit mode)
        Rectangle {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
        }

        // Delete button appears only in edit mode
        Controls.Button {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            text: i18n("Delete Service")
            icon.name: "edit-delete"
            Layout.fillWidth: true
            onClicked: confirmDeleteDialog.open()
        }
    }

    // Timer to debounce favicon fetching when URL changes
    Timer {
        id: faviconFetchTimer
        interval: 500
        onTriggered: {
            if (root.useFavicon && root.isUrlValid) {
                fetchFaviconPreviews();
            }
        }
    }

    // Listen for favicon source ready signals from FaviconCache
    Connections {
        target: typeof faviconCache !== "undefined" ? faviconCache : null

        function onFaviconSourceReady(serviceUrl, source, localPath) {
            if (serviceUrlField.text && serviceUrl === serviceUrlField.text.trim()) {
                if (source === 0) { // Google
                    root.googleFaviconUrl = localPath;
                    root.googleFaviconLoading = false;
                } else if (source === 1) { // IconHorse
                    root.iconHorseFaviconUrl = localPath;
                    root.iconHorseFaviconLoading = false;
                }
            }
        }
    }

    IconThemes.IconDialog {
        id: iconDialog
        onAccepted: {
            if (typeof iconName !== "undefined" && iconName) {
                root.selectedIconName = iconName;
                iconUrlField.text = iconName;
            }
        }
    }

    Kirigami.Dialog {
        id: confirmDeleteDialog
        title: i18n("Delete Service")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: root.deleteRequested()
        Controls.Label {
            text: i18n("Are you sure you want to delete this service? This action cannot be undone.")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }
    }
}
