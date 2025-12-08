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

    // Special workspace: Favorites - show only favorited services
    if (workspace === "__favorites__") {
        for (var i = 0; i < services.length; i++) {
            if (services[i].favorite === true) {
                filtered.push(services[i])
            }
        }
        return addSeparatorsForSpecialWorkspace(filtered)
    }

    // Special workspace: All Services - show all services
    if (workspace === "__all_services__") {
        return addSeparatorsForSpecialWorkspace(services.slice())
    }

    // Normal workspace: filter by workspace property
    for (var i = 0; i < services.length; i++) {
        if (services[i].workspace === workspace) {
            filtered.push(services[i])
        }
    }

    // Mark all items as services for regular workspaces
    for (var i = 0; i < filtered.length; i++) {
        filtered[i] = Object.assign({itemType: "service"}, filtered[i])
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

    // Known OAuth/Auth domains
    var oauthDomains = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
        "facebook.com",
        "www.facebook.com",
        "github.com",
        "api.twitter.com",
        "discord.com",
        "id.twitch.tv",
        "login.yahoo.com",
        "auth.atlassian.com",
        "slack.com",
        "login.salesforce.com",
        "accounts.spotify.com",
        "oauth.telegram.org",
        "web.telegram.org",
        "web.whatsapp.com",
        "firebaseapp.com"
    ]

    // Check domains
    for (var i = 0; i < oauthDomains.length; i++) {
        if (urlStr.indexOf(oauthDomains[i]) !== -1) {
            return true
        }
    }

    // Check patterns
    // We look for specific auth-related patterns in the URL
    // This catches generic OAuth flows and login popups
    if (urlStr.indexOf("oauth") !== -1 ||
        urlStr.indexOf("/auth") !== -1 ||
        (urlStr.indexOf("signin") !== -1 && urlStr.indexOf("google") !== -1) || // narrowing down generic terms
        urlStr.indexOf("response_type=code") !== -1 ||
        urlStr.indexOf("response_type=token") !== -1) {
            return true
    }

    return false
}

// Keep evaluated once in QML engine

// Export names for QML
var _ = {
    findById, indexById, filterByWorkspace, addSeparatorsForSpecialWorkspace, generateUUID, isOAuthUrl
}
