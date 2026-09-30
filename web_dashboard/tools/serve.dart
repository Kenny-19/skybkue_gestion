// Petit serveur statique pour tester le tableau de bord en local.
//
//   dart run web_dashboard/tools/serve.dart [port]
//
// Sert le dossier web_dashboard/ sur http://localhost:8765 (par défaut).
// Existe parce que ni Python ni Node ne sont installés sur le poste de
// développement : le SDK Dart, lui, est toujours là.
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8765;
  final racine = File.fromUri(Platform.script).parent.parent;
  const types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json',
    'webmanifest': 'application/manifest+json',
    'png': 'image/png',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
  };

  final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Tableau de bord : http://localhost:$port');
  await for (final req in serveur) {
    var chemin = Uri.decodeComponent(req.uri.path);
    if (chemin == '/') chemin = '/index.html';
    final fichier = File('${racine.path}$chemin');
    // Pas de sortie du dossier servi.
    if (chemin.contains('..') || !fichier.existsSync()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      continue;
    }
    final ext = chemin.split('.').last.toLowerCase();
    req.response.headers.set(
        HttpHeaders.contentTypeHeader, types[ext] ?? 'application/octet-stream');
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    await req.response.addStream(fichier.openRead());
    await req.response.close();
  }
}
