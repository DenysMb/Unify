// Anti-detection script for browser compatibility
// This script removes/masks properties that websites use to detect embedded browsers
// Updated to be consistent with Firefox user agent

.pragma library

var script = `
(function() {
    // Only run once per page
    if (window.__antiDetectionApplied) return;
    window.__antiDetectionApplied = true;

    // 1. Remove webdriver property (primary detection method)
    Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined,
        configurable: true
    });

    // 2. Override plugins to simulate Firefox (Firefox typically has fewer plugins)
    const fakePlugins = {
        length: 0,
        item: function(i) { return null; },
        namedItem: function(name) { return null; },
        refresh: function() {}
    };

    Object.defineProperty(navigator, 'plugins', {
        get: () => fakePlugins,
        configurable: true
    });

    // 3. Override mimeTypes to be consistent with Firefox
    const fakeMimeTypes = {
        length: 0,
        item: function(i) { return null; },
        namedItem: function(name) { return null; }
    };

    Object.defineProperty(navigator, 'mimeTypes', {
        get: () => fakeMimeTypes,
        configurable: true
    });

    // 4. Override languages
    Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en'],
        configurable: true
    });

    Object.defineProperty(navigator, 'language', {
        get: () => 'en-US',
        configurable: true
    });

    // 5. Do NOT set window.chrome - Firefox doesn't have this object
    // This was causing inconsistency detection (Firefox UA + chrome object = suspicious)
    if (window.chrome) {
        delete window.chrome;
    }

    // 6. Override permissions API
    if (navigator.permissions && navigator.permissions.query) {
        const originalQuery = navigator.permissions.query.bind(navigator.permissions);
        navigator.permissions.query = function(parameters) {
            if (parameters.name === 'notifications') {
                return Promise.resolve({ state: Notification.permission, onchange: null });
            }
            return originalQuery(parameters);
        };
    }

    // 7. Mask WebGL fingerprinting with Firefox-like values
    try {
        const getParameterOrig = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(parameter) {
            if (parameter === 37445) return 'Mozilla';
            if (parameter === 37446) return 'Mozilla';
            return getParameterOrig.call(this, parameter);
        };

        const getParameter2Orig = WebGL2RenderingContext.prototype.getParameter;
        WebGL2RenderingContext.prototype.getParameter = function(parameter) {
            if (parameter === 37445) return 'Mozilla';
            if (parameter === 37446) return 'Mozilla';
            return getParameter2Orig.call(this, parameter);
        };
    } catch (e) {}

    // 8. Override connection info (NetworkInformation API - limited in Firefox)
    // Firefox has limited support for this API, so we make it undefined
    try {
        Object.defineProperty(navigator, 'connection', {
            get: () => undefined,
            configurable: true
        });
    } catch (e) {}

    // 9. Override hardwareConcurrency
    Object.defineProperty(navigator, 'hardwareConcurrency', {
        get: () => 8,
        configurable: true
    });

    // 10. Override deviceMemory (Firefox doesn't support this, should be undefined)
    try {
        Object.defineProperty(navigator, 'deviceMemory', {
            get: () => undefined,
            configurable: true
        });
    } catch (e) {}

    // 11. Remove QtWebEngine-specific properties that may leak
    try {
        // Hide any Qt-specific objects
        if (window.qt) delete window.qt;
        if (window.QtWebEngine) delete window.QtWebEngine;
    } catch (e) {}

    // 12. Override buildID for Firefox consistency
    try {
        Object.defineProperty(navigator, 'buildID', {
            get: () => '20181001000000',
            configurable: true
        });
    } catch (e) {}

    // 13. Track Ctrl key state for link opening behavior
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

    // Reset on window blur (in case key is released while window not focused)
    window.addEventListener('blur', function() {
        window.__unifyCtrlPressed = false;
    });

    console.log('🛡️ Anti-detection script loaded successfully (Firefox mode)');
})();
`;

function getScript() {
    return script;
}
