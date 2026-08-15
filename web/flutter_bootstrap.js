{{flutter_js}}
{{flutter_build_config}}

// Service-worker lifecycle is managed explicitly by index.html. Passing no
// serviceWorkerSettings prevents Flutter's deprecated generated worker from
// competing for the same scope.
_flutter.loader.load({
  config: {
    // Keep CanvasKit on the same origin; no runtime request is sent to Google.
    canvasKitBaseUrl: 'canvaskit/',
    fontFallbackBaseUrl: 'fallback_fonts/',
  },
});
