.pragma library

function findById(services, id) {
    if (!services) return null
    for (var i = 0; i < services.length; i++) {
        if (services[i].id === id) return services[i]
    }
    return null
}

function indexById(services, id) {
    if (!services) return -1
    for (var i = 0; i < services.length; i++) {
        if (services[i].id === id) return i
    }
    return -1
}

function addSeparatorsForSpecialWorkspace(services) {
    if (!services || services.length === 0) return []

    var result = []
    var lastWorkspace = null

    for (var i = 0; i < services.length; i++) {
        var service = services[i]
        var currentWs = service.workspace || ""

        // Insert separator if workspace changed (and not the first item)
        if (lastWorkspace !== null && currentWs !== lastWorkspace) {
            result.push({
                itemType: "separator",
                id: "sep_" + i + "_" + Date.now()
            })
        }

        // Add service with type marker
        result.push(Object.assign({itemType: "service"}, service))

        lastWorkspace = currentWs
    }

    return result
}

function filterByWorkspace(services, workspace) {
    if (!services) return []

    var filtered = []

    // Special workspace: Favorites - show only favorited services (no shortcuts in favorites)
    if (workspace === "__favorites__") {
        for (var i = 0; i < services.length; i++) {
            if (services[i].favorite === true && services[i].itemType !== "shortcut") {
                filtered.push(services[i])
            }
        }
        return addSeparatorsForSpecialWorkspace(filtered)
    }

    // Special workspace: All Services - show all services (no shortcuts)
    if (workspace === "__all_services__") {
        var allServices = []
        for (var i = 0; i < services.length; i++) {
            if (services[i].itemType !== "shortcut") {
                allServices.push(services[i])
            }
        }
        return addSeparatorsForSpecialWorkspace(allServices)
    }

    // Normal workspace: filter by workspace property
    var webServices = []
    var shortcuts = []

    for (var i = 0; i < services.length; i++) {
        if (services[i].workspace === workspace) {
            if (services[i].itemType === "shortcut") {
                shortcuts.push(services[i])
            } else {
                webServices.push(services[i])
            }
        }
    }

    // Add web services first
    for (var i = 0; i < webServices.length; i++) {
        filtered.push(Object.assign({itemType: "service"}, webServices[i]))
    }

    // Add separator before shortcuts if both exist
    if (webServices.length > 0 && shortcuts.length > 0) {
        filtered.push({
            itemType: "separator",
            id: "sep_shortcuts_" + Date.now()
        })
    }

    // Add shortcuts
    for (var i = 0; i < shortcuts.length; i++) {
        filtered.push(Object.assign({}, shortcuts[i]))
    }

    return filtered
}

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0
        var v = c == 'x' ? r : (r & 0x3 | 0x8)
        return v.toString(16)
    })
}

function isOAuthUrl(url) {
    if (!url) return false
    var urlStr = url.toString().toLowerCase()

    // Only Google OAuth for now - other providers don't seem to have issues
    var oauthDomains = [
        "accounts.google.com"
    ]

    // Check domains
    for (var i = 0; i < oauthDomains.length; i++) {
        if (urlStr.indexOf(oauthDomains[i]) !== -1) {
            return true
        }
    }

    // Check for Google-specific OAuth patterns
    if (urlStr.indexOf("accounts.google.com") !== -1 &&
        (urlStr.indexOf("oauth") !== -1 || 
         urlStr.indexOf("signin") !== -1 ||
         urlStr.indexOf("response_type=code") !== -1 ||
         urlStr.indexOf("response_type=token") !== -1)) {
            return true
    }

    return false
}

// Keep evaluated once in QML engine

// Export names for QML
var _ = {
    findById, indexById, filterByWorkspace, addSeparatorsForSpecialWorkspace, generateUUID, isOAuthUrl
}
