import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router/app_router.dart';
import 'core/session.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Api.instance.init();
  final session = Session();
  // Boot real backends and restore any stored session.
  await session.boot();

  runApp(KliqApp(session: session));
}

class KliqApp extends StatefulWidget {
  const KliqApp({super.key, required this.session});

  final Session session;

  @override
  State<KliqApp> createState() => _KliqAppState();
}

class _KliqAppState extends State<KliqApp> {
  late final router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.session),
      ],
      child: MaterialApp.router(
        title: 'KLIQ',
        debugShowCheckedModeBanner: false,
        theme: buildKliqTheme(),
        routerConfig: router,
      ),
    );
  }
}
