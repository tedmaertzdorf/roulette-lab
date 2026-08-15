import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final Directory output = Directory('build/web');
  if (!output.existsSync()) {
    stderr.writeln('build/web ontbreekt; voer eerst flutter build web uit.');
    exitCode = 2;
    return;
  }

  // `--pwa-strategy none` still emits an empty deprecated Flutter worker.
  // Our worker is the sole owner of the root scope.
  for (final String generatedName in const <String>[
    'flutter_service_worker.js',
    '.last_build_id',
    'model_worker.js.deps',
    'model_worker.js.map',
  ]) {
    final File generatedFile = File('${output.path}/$generatedName');
    if (generatedFile.existsSync()) {
      generatedFile.deleteSync();
    }
  }

  final List<File> files =
      output
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((File file) => !file.path.endsWith('service_worker.js'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  final List<String> paths = <String>[];
  int hash = 0xcbf29ce484222325;
  for (final File file in files) {
    final String relative = file.path
        .substring(output.path.length + 1)
        .replaceAll('\\', '/');
    paths.add(relative);
    for (final int byte in file.readAsBytesSync()) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
  }

  final String cacheId = hash.toRadixString(16).padLeft(16, '0');
  final String urls = const JsonEncoder.withIndent(
    '  ',
  ).convert(<String>['./', for (final String path in paths) './$path']);
  final String worker =
      '''
const CACHE_PREFIX = 'roulette-lab-';
const CACHE_NAME = `\${CACHE_PREFIX}$cacheId`;
const PRECACHE_URLS = $urls;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all(PRECACHE_URLS.map(async (url) => {
      const response = await fetch(new Request(url, {cache: 'reload'}));
      if (!response.ok) throw new Error(`Precache mislukt: \${url}`);
      await cache.put(url, response);
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        const cache = await caches.open(CACHE_NAME);
        await cache.put('./', response.clone());
        return response;
      } catch (_) {
        return (await caches.match('./')) || (await caches.match('./index.html'));
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      await cache.put(request, response.clone());
    }
    return response;
  })());
});
''';
  File('${output.path}/service_worker.js').writeAsStringSync(worker);
  stdout.writeln(
    'service_worker.js: ${paths.length} bestanden, cache $cacheId',
  );
}
