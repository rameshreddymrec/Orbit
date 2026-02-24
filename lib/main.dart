/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:async';
import 'dart:io' show Platform, File, Directory;

import 'package:flutter/foundation.dart';

import 'package:orbit/Helpers/config.dart';
import 'package:orbit/Helpers/handle_native.dart';
import 'package:orbit/Helpers/import_export_playlist.dart';
import 'package:orbit/Helpers/logging.dart';
import 'package:orbit/Helpers/route_handler.dart';
import 'package:orbit/Screens/Common/routes.dart';
import 'package:orbit/Screens/Player/audioplayer.dart';
import 'package:orbit/constants/constants.dart';
import 'package:orbit/constants/languagecodes.dart';
import 'package:orbit/providers/audio_service_provider.dart';
import 'package:orbit/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:logging/logging.dart';
// import 'package:metadata_god/metadata_god.dart';  // Commented out to avoid NDK issues
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sizer/sizer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await Hive.initFlutter('Orbit/Database');
    } else if (Platform.isIOS) {
      await Hive.initFlutter('Database');
    } else {
      await Hive.initFlutter();
    }
  } else {
    await Hive.initFlutter();
  }

  // Open settings box first as it is essential for app configuration and services
  await openHiveBox('settings');

  // Parallelize remaining initializations
  await Future.wait([
    Future.wait(
      hiveBoxes.where((box) => box['name'] != 'settings').map((box) async {
        try {
          await openHiveBox(
            box['name'].toString(),
            limit: box['limit'] as bool? ?? false,
          );
        } catch (e) {
          // Error is handled in openHiveBox
        }
      }),
    ),
    if (!kIsWeb && Platform.isAndroid) setOptimalDisplayMode(),
    () async {
      try {
        await startService();
      } finally {
        if (!GetIt.I.isRegistered<MyTheme>()) {
          GetIt.I.registerSingleton<MyTheme>(MyTheme());
        }
      }
    }(),
  ]);

  runApp(MyApp());
}

Future<void> setOptimalDisplayMode() async {
  await FlutterDisplayMode.setHighRefreshRate();
  // final List<DisplayMode> supported = await FlutterDisplayMode.supported;
  // final DisplayMode active = await FlutterDisplayMode.active;

  // final List<DisplayMode> sameResolution = supported
  //     .where(
  //       (DisplayMode m) => m.width == active.width && m.height == active.height,
  //     )
  //     .toList()
  //   ..sort(
  //     (DisplayMode a, DisplayMode b) => b.refreshRate.compareTo(a.refreshRate),
  //   );

  // final DisplayMode mostOptimalMode =
  //     sameResolution.isNotEmpty ? sameResolution.first : active;

  // await FlutterDisplayMode.setPreferredMode(mostOptimalMode);
}

Future<void> startService() async {
  await initializeLogging();
  
  // These services might fail on web or cause issues, so we wrap them
  if (!kIsWeb) {
    // MetadataGod.initialize();  // Commented out to avoid NDK issues
  }
  
  try {
    final audioHandlerHelper = AudioHandlerHelper();
    final AudioPlayerHandler audioHandler =
        await audioHandlerHelper.getAudioHandler();
    GetIt.I.registerSingleton<AudioPlayerHandler>(audioHandler);
  } catch (e) {
    print('ERROR: Failed to initialize AudioHandler: $e');
    // Register a dummy or null handler if needed, or handle in UI
  }
  // MyTheme registration has been moved to main()
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
    Logger.root.severe('Failed to open $boxName Box', error, stackTrace);
    if (!kIsWeb) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String dirPath = dir.path;
      File dbFile = File('$dirPath/$boxName.hive');
      File lockFile = File('$dirPath/$boxName.lock');
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        dbFile = File('$dirPath/Orbit/$boxName.hive');
        lockFile = File('$dirPath/Orbit/$boxName.lock');
      }
      await dbFile.delete();
      await lockFile.delete();
    }
    await Hive.openBox(boxName);
    throw 'Failed to open $boxName Box\nError: $error';
  });
  // clear box if it grows large
  if (limit && box.length > 500) {
    box.clear();
  }
}



class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();

  // ignore: unreachable_from_main
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en', '');
  StreamSubscription? _intentTextStreamSubscription;
  StreamSubscription? _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _intentTextStreamSubscription?.cancel();
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final String? lang = Hive.box('settings').get('lang') as String?;
    if (!kIsWeb) {
      final String systemLangCode = Platform.localeName.substring(0, 2);
      if (lang == null &&
          LanguageCodes.languageCodes.values.contains(systemLangCode)) {
        _locale = Locale(systemLangCode);
      } else {
        _locale = Locale(LanguageCodes.languageCodes[lang ?? 'English'] ?? 'en');
      }
    } else {
      _locale = Locale(LanguageCodes.languageCodes[lang ?? 'English'] ?? 'en');
    }

    AppTheme.currentTheme.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // For sharing or opening urls/text coming from outside the app while the app is in the memory
      _intentTextStreamSubscription =
          ReceiveSharingIntent.getTextStream().listen(
        (String value) {
          Logger.root.info('Received intent on stream: $value');
          handleSharedText(value, navigatorKey);
        },
        onError: (err) {
          Logger.root.severe('ERROR in getTextStream', err);
        },
      );

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then(
        (String? value) {
          Logger.root.info('Received Intent initially: $value');
          if (value != null) handleSharedText(value, navigatorKey);
        },
        onError: (err) {
          Logger.root.severe('ERROR in getInitialTextStream', err);
        },
      );

      // For sharing files coming from outside the app while the app is in the memory
      _intentDataStreamSubscription =
          ReceiveSharingIntent.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty) {
            for (final file in value) {
              if (file.path.endsWith('.json')) {
                final List playlistNames = Hive.box('settings')
                        .get('playlistNames')
                        ?.toList() as List? ??
                    ['Favorite Songs'];
                importFilePlaylist(
                  null,
                  playlistNames,
                  path: file.path,
                  pickFile: false,
                ).then(
                  (value) => navigatorKey.currentState?.pushNamed('/playlists'),
                );
              }
            }
          }
        },
        onError: (err) {
          Logger.root.severe('ERROR in getDataStream', err);
        },
      );

      // For sharing files coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialMedia()
          .then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          for (final file in value) {
            if (file.path.endsWith('.json')) {
              final List playlistNames = Hive.box('settings')
                      .get('playlistNames')
                      ?.toList() as List? ??
                  ['Favorite Songs'];
              importFilePlaylist(
                null,
                playlistNames,
                path: file.path,
                pickFile: false,
              ).then(
                (value) => navigatorKey.currentState?.pushNamed('/playlists'),
              );
            }
          }
        }
      });
    }
  }

  void setLocale(Locale value) {
    setState(() {
      _locale = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: AppTheme.themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                ? Brightness.light
                : Brightness.dark
            : AppTheme.themeMode == ThemeMode.dark
                ? Brightness.light
                : Brightness.dark,
        systemNavigationBarIconBrightness:
            AppTheme.themeMode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark
                : AppTheme.themeMode == ThemeMode.dark
                    ? Brightness.light
                    : Brightness.dark,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OrientationBuilder(
            builder: (context, orientation) {
              SizerUtil.setScreenSize(constraints, orientation);
              return MaterialApp(
                builder: (context, child) {
                  return ScrollConfiguration(
                    behavior: const NoGlowScrollBehavior(),
                    child: child!,
                  );
                },
                title: 'Orbit',
                restorationScopeId: 'orbit',
                debugShowCheckedModeBanner: false,
                themeMode: AppTheme.themeMode,
                theme: AppTheme.lightTheme(
                  context: context,
                ),
                darkTheme: AppTheme.darkTheme(
                  context: context,
                ),
                locale: _locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: LanguageCodes.languageCodes.entries
                    .map((languageCode) => Locale(languageCode.value, ''))
                    .toList(),
                routes: namedRoutes,
                navigatorKey: navigatorKey,
                onGenerateRoute: (RouteSettings settings) {
                  if (settings.name == '/player') {
                    return PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => const PlayScreen(),
                    );
                  }
                  return HandleRoute.handleRoute(settings.name);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
