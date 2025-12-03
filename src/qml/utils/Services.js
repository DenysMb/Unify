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

// Keep evaluated once in QML engine

// Export names for QML
var _ = {
    findById, indexById, filterByWorkspace, addSeparatorsForSpecialWorkspace, generateUUID
}
