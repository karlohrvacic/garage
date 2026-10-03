{{flutter_js}}
{{flutter_build_config}}

// The splash in index.html is on screen before this file has been fetched.
// Loading moves its bar; Flutter's first frame removes it and leaves a mark
// that scripts/measure_first_frame.sh and scripts/look_at_web.sh read.
(() => {
  const progress = document.getElementById('splash-progress');
  const advance = (fraction) => {
    if (progress) progress.style.width = `${Math.round(fraction * 100)}%`;
  };
  advance(0.2);

  window.addEventListener(
    'flutter-first-frame',
    () => {
      performance.mark('garage-first-frame');
      window.__garageFirstFrame = true;
      document.getElementById('splash')?.remove();
    },
    { once: true },
  );

  _flutter.loader.load({
    // Kept as the default bootstrap has it: the worker Flutter generates only
    // unregisters any older one a browser still has.
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async (engineInitializer) => {
      advance(0.6);
      const appRunner = await engineInitializer.initializeEngine();
      advance(0.9);
      await appRunner.runApp();
    },
  });
})();
