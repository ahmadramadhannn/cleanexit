import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'di.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/viewmodels/history_cubit.dart';
import 'presentation/viewmodels/session_cubit.dart';
import 'presentation/viewmodels/settings_cubit.dart';

class CleanExitApp extends StatelessWidget {
  const CleanExitApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Providers sit ABOVE MaterialApp so dialogs & routes can read them too.
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SessionCubit(
            scanner: Services.scanner,
            watcher: Services.watcher,
            store: Services.sessions,
          ),
        ),
        BlocProvider(
          create: (_) => HistoryCubit(
            store: Services.sessions,
            vault: Services.vault,
          ),
        ),
        BlocProvider(create: (_) => SettingsCubit()),
      ],
      child: MaterialApp(
        title: '${CeConstants.appName} — ${CeConstants.tagline}',
        debugShowCheckedModeBanner: false,
        theme: buildCleanExitTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
