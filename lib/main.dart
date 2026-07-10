import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_mode.dart';
import 'core/router/app_router.dart';
import 'core/session.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final mode = await AppModeController.load();
  await Api.instance.init(mode);
  final session = Session(mode);
  // If a mode was chosen in a previous run, boot straight into it.
  // Firebase/Supabase are only ever initialised inside boot() in live mode.
  if (mode.isChosen) await session.boot();

  runApp(KliqApp(mode: mode, session: session));
}

class KliqApp extends StatefulWidget {
  const KliqApp({super.key, required this.mode, required this.session});

  final AppModeController mode;
  final Session session;

  @override
  State<KliqApp> createState() => _KliqAppState();
}

class _KliqAppState extends State<KliqApp> {
  late final router = buildRouter(widget.mode, widget.session);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.mode),
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
