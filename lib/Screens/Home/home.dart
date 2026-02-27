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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import 'package:orbit/CustomWidgets/bottom_nav_bar.dart';
import 'package:orbit/CustomWidgets/drawer.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/glass_box.dart';
import 'package:orbit/CustomWidgets/miniplayer.dart';
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/Helpers/backup_restore.dart';
import 'package:orbit/Helpers/downloads_checker.dart';
import 'package:orbit/Helpers/github.dart';
import 'package:orbit/Helpers/route_handler.dart';
import 'package:orbit/Helpers/update.dart';
import 'package:orbit/Helpers/update_helper.dart';
import 'package:orbit/globals.dart';
import 'package:orbit/Screens/Common/routes.dart';
import 'package:orbit/Screens/Home/home_screen.dart';
import 'package:orbit/Screens/Library/library.dart';
import 'package:orbit/Screens/Library/stats.dart';
import 'package:orbit/Screens/LocalMusic/downed_songs.dart';
import 'package:orbit/Screens/LocalMusic/downed_songs_desktop.dart';
import 'package:orbit/Screens/Player/audioplayer.dart';
import 'package:orbit/Screens/Settings/new_settings_page.dart';
import 'package:orbit/Screens/Top Charts/top.dart';

import 'package:orbit/Services/ext_storage_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:persistent_bottom_nav_bar/persistent_tab_view.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  String? appVersion;
  String name =
      Hive.box('settings').get('name', defaultValue: 'Guest') as String;
  bool checkUpdate =
      Hive.box('settings').get('checkUpdate', defaultValue: true) as bool;
  bool autoBackup =
      Hive.box('settings').get('autoBackup', defaultValue: false) as bool;
  List sectionsToShow = Hive.box('settings').get(
    'sectionsToShow',
    defaultValue: ['Home', 'Top Charts', 'Library', 'Stats'],
  ) as List;
  late List<Widget> _screens;
  DateTime? backButtonPressTime;
  final bool useDense = Hive.box('settings').get(
    'useDenseMini',
    defaultValue: false,
  ) as bool;

  void callback() {
    sectionsToShow = Hive.box('settings').get(
      'sectionsToShow',
      defaultValue: ['Home', 'Top Charts', 'Library', 'Stats'],
    ) as List;
    _screens = _createScreens();
    onItemTapped(0);
    setState(() {});
  }

  void onItemTapped(int index) {
    _selectedIndex.value = index;
    _controller.jumpToTab(
      index,
    );
  }

  Future<bool> handleWillPop(BuildContext? context) async {
    if (context == null) return false;
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > const Duration(seconds: 3);

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.exitConfirm,
        duration: const Duration(seconds: 2),
        noAction: true,
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    checkVersion();
    downloadChecker();
    _controller.addListener(() {
      _selectedIndex.value = _controller.index;
    });
    if (!sectionsToShow.contains('Stats')) {
      sectionsToShow.add('Stats');
      Hive.box('settings').put('sectionsToShow', sectionsToShow);
    }
    _screens = _createScreens();
  }

  void checkVersion() {
    appVersion = AppGlobals.appVersion;
    if (checkUpdate) {
      Logger.root.info('Checking for update. Current version: $appVersion');
      GitHub.getLatestRelease().then((Map release) async {
        final String? version = release['version'] as String?;
        final String? changelog = release['changelog'] as String?;
        final bool isForce = release['isForce'] as bool? ?? false;
        Logger.root.info('Latest release version: $version');
        if (version != null &&
            compareVersion(
              version,
              appVersion!,
            )) {
          Logger.root.info('Update available: $version');
          if (mounted) {
            UpdateHelper.showUpdateDialog(
              context: context,
              version: version,
              changelog: changelog,
              isForce: isForce,
            );
          }
        } else {
          Logger.root.info('No update available or version is latest');
        }
      });
    }
    // ... rest of autoBackup logic ...
      if (autoBackup) {
        final List<String> checked = [
          AppLocalizations.of(
            context,
          )!
              .settings,
          AppLocalizations.of(
            context,
          )!
              .downs,
          AppLocalizations.of(
            context,
          )!
              .playlists,
        ];
        final List playlistNames = Hive.box('settings').get(
          'playlistNames',
          defaultValue: ['Favorite Songs'],
        ) as List;
        final Map<String, List> boxNames = {
          AppLocalizations.of(
            context,
          )!
              .settings: ['settings'],
          AppLocalizations.of(
            context,
          )!
              .cache: ['cache'],
          AppLocalizations.of(
            context,
          )!
              .downs: ['downloads'],
          AppLocalizations.of(
            context,
          )!
              .playlists: playlistNames,
        };
        final String autoBackPath = Hive.box('settings').get(
          'autoBackPath',
          defaultValue: '',
        ) as String;
        if (autoBackPath == '') {
          ExtStorageProvider.getExtStorage(
            dirName: 'Orbit/Backups',
            writeAccess: true,
          ).then((value) {
            Hive.box('settings').put('autoBackPath', value);
            if (mounted) {
              createBackup(
                context,
                checked,
                boxNames,
                path: value,
                fileName: 'BlackHole_AutoBackup',
                showDialog: false,
              );
            }
          });
        } else {
          if (mounted) {
            createBackup(
              context,
              checked,
              boxNames,
              path: autoBackPath,
              fileName: 'BlackHole_AutoBackup',
              showDialog: false,
            ).then(
              (value) => {
                if (value.contains('No such file or directory'))
                  {
                    ExtStorageProvider.getExtStorage(
                      dirName: 'Orbit/Backups',
                      writeAccess: true,
                    ).then(
                      (value) {
                        Hive.box('settings').put('autoBackPath', value);
                        if (mounted) {
                          createBackup(
                            context,
                            checked,
                            boxNames,
                            path: value,
                            fileName: 'BlackHole_AutoBackup',
                          );
                        }
                      },
                    ),
                  },
              },
            );
          }
        }
      }
    }

  final PageController _pageController = PageController();
  final PersistentTabController _controller = PersistentTabController(initialIndex: 0);

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool rotated = MediaQuery.sizeOf(context).height < screenWidth;
    final miniplayer = MiniPlayer();
    return GradientContainer(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        drawerEnableOpenDragGesture: false,
        drawer: Drawer(
          child: GradientContainer(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  stretch: true,
                  expandedHeight: MediaQuery.sizeOf(context).height * 0.2,
                  flexibleSpace: FlexibleSpaceBar(
                    title: RichText(
                      text: TextSpan(
                        text: AppLocalizations.of(context)!.appTitle,
                        style: const TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w600,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: appVersion == null ? '' : '\nv$appVersion',
                            style: const TextStyle(
                              fontSize: 7.0,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                    titlePadding: const EdgeInsets.only(bottom: 40.0),
                    centerTitle: true,
                    background: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.1),
                          ],
                        ).createShader(
                          Rect.fromLTRB(0, 0, rect.width, rect.height),
                        );
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        image: AssetImage(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/header-dark.jpg'
                              : 'assets/header.jpg',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      ValueListenableBuilder(
                        valueListenable: _selectedIndex,
                        builder: (
                          BuildContext context,
                          int snapshot,
                          Widget? child,
                        ) {
                          return Column(
                            children: [
                              ListTile(
                                title: Text(
                                  AppLocalizations.of(context)!.home,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                leading: const Icon(
                                  Icons.home_rounded,
                                ),
                                selected: _selectedIndex.value ==
                                    sectionsToShow.indexOf('Home'),
                                selectedColor:
                                    Theme.of(context).colorScheme.secondary,
                                onTap: () {
                                  Navigator.pop(context);
                                  if (_selectedIndex.value != 0) {
                                    onItemTapped(0);
                                  }
                                },
                              ),
                              ListTile(
                                title:
                                    Text(AppLocalizations.of(context)!.myMusic),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                leading: Icon(
                                  MdiIcons.folderMusic,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          (!kIsWeb && (Platform.isWindows ||
                                                  Platform.isLinux ||
                                                  Platform.isMacOS))
                                              ? const DownloadedSongsDesktop()
                                              : const DownloadedSongs(
                                                  showPlaylists: true,
                                                ),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                title:
                                    Text(AppLocalizations.of(context)!.downs),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                leading: Icon(
                                  Icons.download_done_rounded,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/downloads');
                                },
                              ),
                              ListTile(
                                title: Text(
                                  AppLocalizations.of(context)!.playlists,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                leading: Icon(
                                  Icons.playlist_play_rounded,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/playlists');
                                },
                              ),
                              ListTile(
                                title: Text(
                                  AppLocalizations.of(context)!.settings,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                // miscellaneous_services_rounded,
                                leading: const Icon(Icons.settings_rounded),
                                selected: _selectedIndex.value ==
                                    sectionsToShow.indexOf('Settings'),
                                selectedColor:
                                    Theme.of(context).colorScheme.secondary,
                                onTap: () {
                                  Navigator.pop(context);
                                  final idx =
                                      sectionsToShow.indexOf('Settings');
                                  if (idx != -1) {
                                    if (_selectedIndex.value != idx) {
                                      onItemTapped(idx);
                                    }
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            NewSettingsPage(callback: callback),
                                      ),
                                    );
                                  }
                                },
                              ),
                              ListTile(
                                title:
                                    Text(AppLocalizations.of(context)!.about),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                leading: Icon(
                                  Icons.info_outline_rounded,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/about');
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: <Widget>[
                      const Spacer(),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.madeBy,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Row(
          children: [

            if (rotated)
              SizedBox(
                width: 70.0,
                child: ValueListenableBuilder(
                  valueListenable: _selectedIndex,
                  builder: (
                    BuildContext context,
                    int indexValue,
                    Widget? child,
                  ) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraint) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              clipBehavior: Clip.none,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraint.maxHeight,
                                ),
                                child: IntrinsicHeight(
                                  child: NavigationRail(
                                    minWidth: 70,
                                    groupAlignment: -1.0,
                                    backgroundColor: Theme.of(context).cardColor,
                                    selectedIndex: indexValue,
                                    onDestinationSelected: (index) {
                                      onItemTapped(index);
                                    },
                                    labelType: NavigationRailLabelType.none,
                                    selectedLabelTextStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    unselectedLabelTextStyle: TextStyle(
                                      color: Theme.of(context)
                                          .iconTheme
                                          .color,
                                    ),
                                    selectedIconTheme: Theme.of(context).iconTheme.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                    unselectedIconTheme: Theme.of(context).iconTheme,
                                    useIndicator: MediaQuery.sizeOf(context).width < 1050,
                                    indicatorColor: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.4),
                                    leading: homeDrawer(
                                      context: context,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5.0,
                                      ),
                                    ),
                                    destinations:
                                        sectionsToShow.map((section) {
                                      switch (section) {
                                        case 'Home':
                                          return NavigationRailDestination(
                                            icon: const Icon(
                                              CupertinoIcons.house,
                                            ),
                                            selectedIcon: const Icon(
                                              CupertinoIcons.house_fill,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .home,
                                            ),
                                          );
                                        case 'Top Charts':
                                          return NavigationRailDestination(
                                            icon: const Icon(
                                              Icons.equalizer_rounded,
                                            ),
                                            selectedIcon: const Icon(
                                              Icons.equalizer_rounded,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .topCharts,
                                            ),
                                          );
                                        case 'Stats':
                                          return NavigationRailDestination(
                                            icon: const Icon(
                                              CupertinoIcons.chart_pie,
                                            ),
                                            selectedIcon: const Icon(
                                              CupertinoIcons.chart_pie_fill,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .stats,
                                            ),
                                          );
                                        case 'Library':
                                          return NavigationRailDestination(
                                            icon: const Icon(
                                              CupertinoIcons.music_albums,
                                            ),
                                            selectedIcon: const Icon(
                                              CupertinoIcons.music_albums_fill,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .library,
                                            ),
                                          );
                                        default:
                                          return NavigationRailDestination(
                                            icon: const Icon(
                                              Icons.settings_rounded,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .settings,
                                            ),
                                          );
                                      }
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

            Expanded(
              child: Stack(
                children: [
                  PersistentTabView.custom(
                    context,
                    controller: _controller,
                    itemCount: sectionsToShow.length,
                    confineInSafeArea: true,
                    handleAndroidBackButtonPress: true,
                    onWillPop: (context) => handleWillPop(context),
                    screenTransitionAnimation: const ScreenTransitionAnimation(
                      animateTabTransition: false,
                    ),
                    routeAndNavigatorSettings:
                        CustomWidgetRouteAndNavigatorSettings(
                      routes: namedRoutes,
                      onGenerateRoute: (RouteSettings settings) {
                        if (settings.name == '/player') {
                          return PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) => const PlayScreen(),
                          );
                        }
                        return HandleRoute.handleRoute(settings.name);
                      },
                    ),
                    hideNavigationBar: true,
                    customWidget: const SizedBox.shrink(),
                    screens: _createScreens(),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                        child: GlassBox(
                          borderRadius: BorderRadius.circular(25.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                miniplayer,
                                if (!rotated)
                                  ValueListenableBuilder(
                                    valueListenable: _selectedIndex,
                                    builder: (
                                      BuildContext context,
                                      int indexValue,
                                      Widget? child,
                                    ) {
                                      return SizedBox(
                                        height: 60,
                                        child: CustomBottomNavBar(
                                          currentIndex: indexValue,
                                          backgroundColor: Colors.transparent,
                                          selectedColorOpacity: 0.4,
                                          onTap: (index) {
                                            onItemTapped(index);
                                          },
                                          items: _navBarItems(context),
                                        ),
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CustomBottomNavBarItem> _navBarItems(BuildContext context) {
    return sectionsToShow.map((section) {
      switch (section) {
        case 'Home':
          return CustomBottomNavBarItem(
            icon: const Icon(CupertinoIcons.house),
            activeIcon: const Icon(CupertinoIcons.house_fill),
            title: Text(AppLocalizations.of(context)!.home),
            selectedColor: Theme.of(context).colorScheme.secondary,
          );
        case 'Top Charts':
          return CustomBottomNavBarItem(
            icon: const Icon(Icons.equalizer_rounded),
            activeIcon: const Icon(Icons.equalizer_rounded),
            title: Text(
              AppLocalizations.of(context)!.topCharts,
            ),
            selectedColor: Theme.of(context).colorScheme.secondary,
          );
        case 'Stats':
          return CustomBottomNavBarItem(
            icon: const Icon(CupertinoIcons.chart_pie),
            activeIcon: const Icon(CupertinoIcons.chart_pie_fill),
            title: Text(AppLocalizations.of(context)!.stats),
            selectedColor: Theme.of(context).colorScheme.secondary,
          );
        case 'Library':
          return CustomBottomNavBarItem(
            icon: const Icon(CupertinoIcons.music_albums),
            activeIcon: const Icon(CupertinoIcons.music_albums_fill),
            title: Text(AppLocalizations.of(context)!.library),
            selectedColor: Theme.of(context).colorScheme.secondary,
          );
        default:
          return CustomBottomNavBarItem(
            icon: const Icon(Icons.settings_rounded),
            activeIcon: const Icon(Icons.settings_rounded),
            title: Text(
              AppLocalizations.of(context)!.settings,
            ),
            selectedColor: Theme.of(context).colorScheme.secondary,
          );
      }
    }).toList();
  }

  List<Widget> _buildScreens() => _screens;

  List<Widget> _createScreens() {
    return sectionsToShow.map((e) {
      switch (e) {
        case 'Home':
          return HomeScreen(scaffoldKey: _scaffoldKey);
        case 'Top Charts':
          return TopCharts(
            pageController: _pageController,
            scaffoldKey: _scaffoldKey,
          );
        case 'Stats':
          return Stats(scaffoldKey: _scaffoldKey);
        case 'Library':
          return LibraryPage(scaffoldKey: _scaffoldKey);
        default:
          return LibraryPage(scaffoldKey: _scaffoldKey);
      }
    }).toList();
  }
}
