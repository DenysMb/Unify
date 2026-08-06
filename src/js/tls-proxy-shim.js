// SPDX-FileCopyrightText: 2025 Denys Madureira
// SPDX-License-Identifier: GPL-3.0-or-later
//
// fetch() shim that routes requests through the local TLS-impersonating proxy
// (via QWebChannel -> TlsProxyBridge -> cf-proxy.py). Hosts in
// ALWAYS_PROXY_HOSTS are always proxied because Cloudflare's TLS-fingerprint
// bot detection rejects Qt WebEngine outright. Any other request that fails
// with a TypeError (the signature of a Cloudflare-challenged CORS preflight)
// is transparently retried through the proxy as a generic fallback.
// Prepended at runtime with qwebchannel.js, which provides QWebChannel.
// TODO(tls-proxy): XMLHttpRequest and WebSocket are not intercepted yet.

(function () {
    if (window.__unifyTlsProxyInstalled) return;
    window.__unifyTlsProxyInstalled = true;

    // Qt WebEngine renders object args as "[object Object]", hiding page errors;
    // stringify them so failures are visible in the app log
    ["error", "warn"].forEach(function (level) {
        var original = console[level];
        console[level] = function () {
            var args = Array.prototype.map.call(arguments, function (arg) {
                if (arg instanceof Error) return arg.stack || String(arg);
                if (arg && typeof arg === "object") {
                    try {
                        return JSON.stringify(arg);
                    } catch (e) {
                        return String(arg);
                    }
                }
                return arg;
            });
            return original.apply(console, args);
        };
    });

    // Seed until the bridge provides the configured list (ConfigManager.tlsProxyHosts)
    var proxyHosts = ["api.standardnotes.com"];

    var channelPromise = null;
    var channelBridge = null;
    var pending = {};
    var nextId = 1;
    // Unique per page: all pages share one bridge, and fetchResponse is broadcast
    // to every page, so ids must not collide across pages
    var pageId = Math.random().toString(36).slice(2) + Date.now().toString(36);

    function getTransport() {
        if (window.qt && window.qt.webChannelTransport) {
            return window.qt.webChannelTransport;
        }
        return window.__unifyQtTransport || null;
    }

    function ensureChannel() {
        if (channelPromise) return channelPromise;
        channelPromise = new Promise(function (resolve) {
            var transport = getTransport();
            if (!transport || typeof QWebChannel === "undefined") {
                console.warn("[Unify] TLS proxy unavailable: no WebChannel transport");
                resolve(false);
                return;
            }
            try {
                new QWebChannel(transport, function (channel) {
                    var bridge = channel.objects && channel.objects.tlsProxyBridge;
                    if (!bridge) {
                        console.warn("[Unify] TLS proxy unavailable: bridge not registered");
                        resolve(false);
                        return;
                    }
                    channelBridge = bridge;
                    bridge.fetchResponse.connect(function (id, response) {
                        var settle = pending[id];
                        if (!settle) return;
                        delete pending[id];
                        settle(response);
                    });
                    syncHosts(bridge.proxyHosts);
                    bridge.proxyHostsChanged.connect(syncHosts);
                    console.log("[Unify] TLS proxy bridge connected");
                    resolve(true);
                });
            } catch (e) {
                console.warn("[Unify] TLS proxy unavailable:", e);
                resolve(false);
            }
        });
        return channelPromise;
    }
    ensureChannel();

    function syncHosts(hosts) {
        if (!hosts || typeof hosts.length !== "number") return;
        proxyHosts = [];
        for (var i = 0; i < hosts.length; i++) {
            proxyHosts.push(String(hosts[i]));
        }
        console.warn("[Unify] TLS proxy hosts:", proxyHosts.join(", ") || "(none)");
    }

    function bytesToBase64(bytes) {
        var binary = "";
        var chunkSize = 0x8000;
        for (var i = 0; i < bytes.length; i += chunkSize) {
            binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize));
        }
        return btoa(binary);
    }

    function base64ToBytes(base64) {
        var binary = atob(base64);
        var bytes = new Uint8Array(binary.length);
        for (var i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes;
    }

    function bodyToBase64(body) {
        if (body === undefined || body === null) return Promise.resolve("");
        if (typeof body === "string") return Promise.resolve(bytesToBase64(new TextEncoder().encode(body)));
        if (body instanceof URLSearchParams) return Promise.resolve(bytesToBase64(new TextEncoder().encode(body.toString())));
        if (body instanceof ArrayBuffer) return Promise.resolve(bytesToBase64(new Uint8Array(body)));
        if (ArrayBuffer.isView(body)) return Promise.resolve(bytesToBase64(new Uint8Array(body.buffer, body.byteOffset, body.byteLength)));
        if (typeof Blob !== "undefined" && body instanceof Blob) {
            return body.arrayBuffer().then(function (buffer) {
                return bytesToBase64(new Uint8Array(buffer));
            });
        }
        return Promise.reject(new Error("unsupported-body"));
    }

    function normalizeRequest(input, init) {
        var url = "";
        var method = "GET";
        var headers = {};
        var bodyPromise = Promise.resolve("");

        function collectHeaders(source) {
            new Headers(source).forEach(function (value, key) {
                headers[key] = value;
            });
        }

        if (typeof input === "string") {
            url = input;
        } else if (input && input.url) {
            url = input.url;
            method = input.method || method;
            if (input.headers) collectHeaders(input.headers);
            if (method !== "GET" && method !== "HEAD" && input.body !== null) {
                bodyPromise = input.arrayBuffer().then(function (buffer) {
                    return bytesToBase64(new Uint8Array(buffer));
                });
            }
        }
        if (init) {
            if (init.method) method = init.method;
            if (init.headers) collectHeaders(init.headers);
            if (init.body !== undefined) bodyPromise = bodyToBase64(init.body);
        }

        return { url: url, method: method.toUpperCase(), headers: headers, bodyPromise: bodyPromise };
    }

    function proxyFetch(input, init, isRetry) {
        var spec = normalizeRequest(input, init);
        return Promise.all([spec.bodyPromise, ensureChannel()]).then(function (results) {
            if (!results[1]) return Promise.reject(new TypeError("Failed to fetch"));
            var id = pageId + "-" + String(nextId++);
            var request = {
                url: spec.url,
                method: spec.method,
                headers: spec.headers,
                bodyBase64: results[0],
                isRetry: isRetry === true
            };
            return new Promise(function (resolve, reject) {
                pending[id] = function (response) {
                    if (!response || response.error) {
                        reject(new TypeError("Failed to fetch"));
                        return;
                    }
                    var status = response.status || 0;
                    var body = status === 204 || status === 304 ? null : base64ToBytes(response.bodyBase64 || "");
                    try {
                        resolve(new Response(body, { status: status, headers: response.headers || {} }));
                    } catch (e) {
                        reject(new TypeError("Failed to fetch"));
                    }
                };
                channelBridge.fetchViaProxy(id, request);
            });
        });
    }

    var originalFetch = window.fetch;

    window.fetch = function (input, init) {
        var url = typeof input === "string" ? input : (input && input.url) || "";

        // Never route data:/blob: URLs through the proxy (e.g. WASM loaders)
        if (/^(data|blob):/i.test(url)) {
            return originalFetch.call(window, input, init);
        }

        var host = "";
        try {
            host = new URL(url, window.location.href).hostname;
        } catch (e) {}

        if (proxyHosts.indexOf(host) !== -1) {
            return proxyFetch(input, init, false).catch(function (error) {
                console.warn("[Unify] TLS proxy fetch failed, falling back to direct fetch:", error && error.message);
                return originalFetch.call(window, input, init);
            });
        }

        return originalFetch.call(window, input, init).catch(function (error) {
            if (!(error instanceof TypeError)) throw error;
            console.warn("[Unify] TLS proxy retry after direct failure:", url.slice(0, 120));
            return proxyFetch(input, init, true).catch(function () {
                throw error;
            });
        });
    };
})();
