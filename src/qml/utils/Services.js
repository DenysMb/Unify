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

function filterByWorkspace(services, workspace) {
    if (!services) return []
    var out = []
    for (var i = 0; i < services.length; i++) {
        if (services[i].workspace === workspace) out.push(services[i])
    }
    return out
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
    findById, indexById, filterByWorkspace, generateUUID
}
