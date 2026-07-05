// Anti-detection script for browser compatibility
// Qt WebEngine is Chromium-based. Only override what leaks the embedded context.
// Intentionally minimal: every override risks creating detectable inconsistencies.

.pragma library

var baseScript = `
(function() {
    if (window.__antiDetectionApplied) return;
    window.__antiDetectionApplied = true;

    // 0. Intercept all JavaScript errors for diagnostics
    window.addEventListener('error', function(e) {
        if (e.message && e.filename) {
            console.log('[Unify] JS error:', e.message, 'at', e.filename + ':' + e.lineno);
        }
    }, true);
    window.addEventListener('unhandledrejection', function(e) {
        console.log('[Unify] Unhandled rejection:', e.reason);
    }, true);

    // 1. Remove QtWebEngine-specific properties that leak the embedding context
    try {
        if (window.qt) delete window.qt;
        if (window.QtWebEngine) delete window.QtWebEngine;
    } catch (e) {}

    // 2. Remove webdriver property (set by --enable-automation or automation tools)
    try {
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
            configurable: true
        });
    } catch (e) {}

    // 3. Track Ctrl key state for link opening behavior
    window.__unifyCtrlPressed = false;

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Control' || e.ctrlKey) {
            window.__unifyCtrlPressed = true;
        }
    }, true);

    document.addEventListener('keyup', function(e) {
        if (e.key === 'Control') {
            window.__unifyCtrlPressed = false;
        }
    }, true);

    window.addEventListener('blur', function() {
        window.__unifyCtrlPressed = false;
    });
`;

var chromePolyfills = `
    // 4. Chrome-specific polyfills (only for Chrome UA services like Linear)
    if (!window.chrome) {
        window.chrome = {
            runtime: {},
            loadTimes: function() {},
            csi: function() {}
        };
    }

    if (!navigator.plugins || navigator.plugins.length === 0) {
        try {
            Object.defineProperty(navigator, 'plugins', {
                get: function() {
                    var arr = [{
                        name: 'Chrome PDF Plugin',
                        filename: 'internal-pdf-viewer',
                        description: 'Portable Document Format',
                        length: 1
                    }];
                    arr.item = function(i) { return this[i] || null; };
                    arr.namedItem = function(n) { return null; };
                    arr.refresh = function() {};
                    return arr;
                },
                configurable: true
            });
        } catch (e) {}
    }

    if (!navigator.mimeTypes || navigator.mimeTypes.length === 0) {
        try {
            Object.defineProperty(navigator, 'mimeTypes', {
                get: function() {
                    var arr = [{
                        type: 'application/pdf',
                        suffixes: 'pdf',
                        description: 'Portable Document Format'
                    }];
                    arr.item = function(i) { return this[i] || null; };
                    arr.namedItem = function(n) { return null; };
                    return arr;
                },
                configurable: true
            });
        } catch (e) {}
    }
`;

var closingTag = `
})();
`;

function getScript(isChrome) {
    var script = baseScript;
    if (isChrome) {
        script += chromePolyfills;
    }
    script += closingTag;
    return script;
}