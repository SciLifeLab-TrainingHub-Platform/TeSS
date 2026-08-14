(function () {
    "use strict";

    var CAL_SCRIPT_URL = "https://app.cal.com/embed/embed.js";
    var CAL_ORIGIN = "https://app.cal.com";

    // Adapted from Cal.com's embed loader. Preserve its queued calls and
    // namespace initialization when updating this integration.
    function ensureCalLoader() {
        (function (C, A, L) {
            var push = function (api, args) { api.q.push(args); };
            var document = C.document;

            C.Cal = C.Cal || function () {
                var cal = C.Cal;
                var args = arguments;

                if (!cal.loaded) {
                    cal.ns = {};
                    cal.q = cal.q || [];
                    document.head.appendChild(document.createElement("script")).src = A;
                    cal.loaded = true;
                }

                if (args[0] === L) {
                    var api = function () { push(api, arguments); };
                    var namespace = args[1];
                    api.q = api.q || [];

                    if (typeof namespace === "string") {
                        cal.ns[namespace] = cal.ns[namespace] || api;
                        push(cal.ns[namespace], args);
                        push(cal, ["initNamespace", namespace]);
                    } else {
                        push(cal, args);
                    }
                    return;
                }

                push(cal, args);
            };
        })(window, CAL_SCRIPT_URL, "init");

        return window.Cal;
    }

    function setFailureState(root) {
        var calendar = root.querySelector("[data-cal-calendar]");
        var fallback = root.querySelector("[data-cal-fallback]");
        var status = root.querySelector("[data-cal-status]");

        calendar.hidden = true;
        calendar.removeAttribute("aria-busy");
        fallback.hidden = false;
        status.textContent = status.getAttribute("data-failure-message");
    }

    function setReadyState(namespace) {
        document.querySelectorAll("[data-cal-embed]").forEach(function (root) {
            if (root.getAttribute("data-cal-namespace") !== namespace) return;

            root.querySelector("[data-cal-calendar]").removeAttribute("aria-busy");
            root.querySelector("[data-cal-fallback]").hidden = true;
            root.querySelector("[data-cal-status]").textContent = "";
        });
    }

    function setNamespaceFailureState(namespace) {
        document.querySelectorAll("[data-cal-embed]").forEach(function (root) {
            if (root.getAttribute("data-cal-namespace") === namespace) setFailureState(root);
        });
    }

    function bindNamespaceEvents(namespaceApi, namespace) {
        if (namespaceApi.resourcesBookingEventsBound) return;

        namespaceApi.resourcesBookingEventsBound = true;
        namespaceApi("on", {
            action: "linkReady",
            callback: function () { setReadyState(namespace); }
        });
        namespaceApi("on", {
            action: "linkFailed",
            callback: function () { setNamespaceFailureState(namespace); }
        });
    }

    function bindScriptFailureHandler(script) {
        if (!script || script.hasAttribute("data-resources-booking-error-listener")) return;

        script.setAttribute("data-resources-booking-error-listener", "true");
        script.addEventListener("error", function () {
            document.querySelectorAll("[data-cal-embed]").forEach(setFailureState);
            script.parentNode.removeChild(script);

            // The failed loader leaves Cal.loaded set to true. Removing the queued
            // stub allows a later Turbolinks visit to request the script again.
            if (window.Cal && window.Cal.loaded && window.Cal.q) delete window.Cal;
        }, { once: true });
    }

    function loadCalendar(root) {
        if (root.hasAttribute("data-cal-initialized")) return;

        var namespace = root.getAttribute("data-cal-namespace");
        var calLink = root.getAttribute("data-cal-link");
        var calendar = root.querySelector("[data-cal-calendar]");
        var status = root.querySelector("[data-cal-status]");
        var Cal = ensureCalLoader();

        root.setAttribute("data-cal-initialized", "true");
        calendar.hidden = false;
        calendar.setAttribute("aria-busy", "true");
        status.textContent = status.getAttribute("data-loading-message");

        Cal("init", namespace, { origin: CAL_ORIGIN });

        var namespaceApi = Cal.ns[namespace];
        bindNamespaceEvents(namespaceApi, namespace);
        namespaceApi("inline", {
            elementOrSelector: calendar,
            config: {
                layout: "month_view",
                useSlotsViewOnSmallScreen: true
            },
            calLink: calLink
        });
        namespaceApi("ui", {
            cssVarsPerTheme: {
                light: { "cal-brand": "#a7c947" },
                dark: { "cal-brand": "#fafafa" }
            },
            hideEventTypeDetails: false,
            layout: "month_view"
        });

        var script = document.querySelector('script[src="' + CAL_SCRIPT_URL + '"]');
        bindScriptFailureHandler(script);
    }

    function initializeBookingEmbeds() {
        document.querySelectorAll("[data-cal-embed]").forEach(loadCalendar);
    }

    function resetBookingEmbedsBeforeCache() {
        document.querySelectorAll("[data-cal-embed]").forEach(function (root) {
            var calendar = root.querySelector("[data-cal-calendar]");
            var fallback = root.querySelector("[data-cal-fallback]");
            var status = root.querySelector("[data-cal-status]");

            calendar.innerHTML = "";
            calendar.hidden = true;
            calendar.removeAttribute("aria-busy");
            fallback.hidden = false;
            status.textContent = "";
            root.removeAttribute("data-cal-initialized");
        });
    }

    document.addEventListener("turbolinks:load", initializeBookingEmbeds);
    document.addEventListener("turbolinks:before-cache", resetBookingEmbedsBeforeCache);
})();
