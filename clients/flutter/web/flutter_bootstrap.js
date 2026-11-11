// Flutter Web bootstrap controlled by VENCIRA. Flutter substitutes these
// template tokens during "flutter build web" (do not remove them).
{{flutter_js}}
{{flutter_build_config}}

// Bundle CanvasKit with the app instead of fetching a runtime from a CDN.
// This is important on private networks and avoids a third-party dependency.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/canvaskit/"
  }
});
