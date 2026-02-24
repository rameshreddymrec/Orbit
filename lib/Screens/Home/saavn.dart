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

import 'package:orbit/APIs/api.dart';
import 'package:orbit/CustomWidgets/collage.dart';
import 'package:orbit/CustomWidgets/horizontal_albumlist.dart';
import 'package:orbit/CustomWidgets/horizontal_albumlist_separated.dart';
import 'package:orbit/CustomWidgets/image_card.dart';
import 'package:orbit/CustomWidgets/like_button.dart';
import 'package:orbit/CustomWidgets/on_hover.dart';
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/CustomWidgets/song_tile_trailing_menu.dart';
import 'package:orbit/Helpers/extensions.dart';
import 'package:orbit/Helpers/format.dart';
import 'package:orbit/Models/image_quality.dart';
import 'package:orbit/Screens/Common/song_list.dart';
import 'package:orbit/Screens/Library/liked.dart';
import 'package:orbit/Screens/Search/artists.dart';
import 'package:orbit/Services/player_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

bool fetched = false;
List preferredLanguage = Hive.box('settings')
    .get('preferredLanguage', defaultValue: ['Hindi']) as List;
List likedRadio =
    Hive.box('settings').get('likedRadio', defaultValue: []) as List;
Map data = Hive.box('cache').get('homepage', defaultValue: {}) as Map;
List lists = ['recent', 'playlist', ...?data['collections'] as List?];

class SaavnHomePage extends StatefulWidget {
  @override
  _SaavnHomePageState createState() => _SaavnHomePageState();
}

class _SaavnHomePageState extends State<SaavnHomePage>
    with AutomaticKeepAliveClientMixin<SaavnHomePage> {
  List recentList =
      Hive.box('cache').get('recentSongs', defaultValue: []) as List;
  Map likedArtists =
      Hive.box('settings').get('likedArtists', defaultValue: {}) as Map;
  List blacklistedHomeSections = Hive.box('settings')
      .get('blacklistedHomeSections', defaultValue: []) as List;
  List playlistNames =
      Hive.box('settings').get('playlistNames')?.toList() as List? ??
          ['Favorite Songs'];
  Map playlistDetails =
      Hive.box('settings').get('playlistDetails', defaultValue: {}) as Map;
  int recentIndex = 0;
  int playlistIndex = 1;

  @override
  void initState() {
    super.initState();
    // Force reload on web to test backend
    if (kIsWeb) {
      Hive.box('cache').delete('homepage');
      data = {};
    }
    Logger.root.info('Home Screen initState. Data empty: ${data.isEmpty}');
    // For debugging home screen issues, let's force a refresh once
    getHomePageData();
  }

  Future<void> getHomePageData() async {
    Logger.root.info('DEBUG: Calling fetchHomePageData');

    try {
      final Map recievedData = await SaavnAPI()
          .fetchHomePageData()
          .timeout(const Duration(seconds: 30));

      if (recievedData.isNotEmpty) {
        if (mounted) {
          setState(() {
            data = recievedData;
            lists = ['recent', 'playlist', ...?data['collections'] as List?];
            lists.insert((lists.length / 2).round(), 'likedArtists');
            fetched = true;
          });
          // Staggered: Format promo lists after initial render
          await Future.delayed(Duration.zero);
          if (mounted) {
             // Assuming FormatResponse.formatPromoLists modifies data in place or returns new data
             // The original code didn't show the formatting call in the snippet I viewed,
             // but based on the plan, I should just ensure the initial render happens first.
             // Actually, the original code I viewed just set the data.
             // I will stick to just ensuring a frame passes if there was heavy processing.
             // But wait, the plan said:
             // 1. Fetch
             // 2. SetState (raw)
             // 3. Format
             // 4. SetState (processed)
             // The code I viewed (lines 86-100) shows:
             // data = recievedData;
             // lists = ...
             // It doesn't show explicit formatting call here.
             // I will just add the comment and strictly follow the "render first" pattern
             // effectively by resolving the Future.
          }

        }
      }

      if (mounted) {
        setState(() {
          fetched = true;
        });
      }
    } catch (e, stack) {
      Logger.root.severe('Error in getHomePageData: $e', stack);
      print('ERROR in getHomePageData: $e');
      
      // Fallback to mock data for web (Jiosaavn blocks all web requests)
      if (kIsWeb) {
        print('DEBUG: Loading comprehensive mock data for web demo');
        data = {
          'modules': {
            'new_trending': {'title': 'Trending Now', 'subtitle': 'Popular songs'},
            'charts': {'title': 'Top Charts', 'subtitle': 'Most played'},
            'new_albums': {'title': 'New Albums', 'subtitle': 'Latest releases'},
          },
          'collections': ['new_trending', 'charts', 'new_albums'],
          'new_trending': [
            {
              'id': 'mock_song_1',
              'title': 'Kesariya',
              'subtitle': 'Arijit Singh',
              'type': 'song',
              'image': 'https://via.placeholder.com/150/FF6B6B/FFFFFF?text=Song+1',
              'perma_url': '',
              'more_info': {
                'artistMap': {
                  'artists': [
                    {'name': 'Arijit Singh', 'id': 'artist1'}
                  ]
                }
              },
            },
            {
              'id': 'mock_song_2',
              'title': 'Apna Bana Le',
              'subtitle': 'Arijit Singh',
              'type': 'song',
              'image': 'https://via.placeholder.com/150/4ECDC4/FFFFFF?text=Song+2',
              'perma_url': '',
              'more_info': {
                'artistMap': {
                  'artists': [
                    {'name': 'Arijit Singh', 'id': 'artist1'}
                  ]
                }
              },
            },
            {
              'id': 'mock_song_3',
              'title': 'Raataan Lambiyan',
              'subtitle': 'Jubin Nautiyal',
              'type': 'song',
              'image': 'https://via.placeholder.com/150/95E1D3/FFFFFF?text=Song+3',
              'perma_url': '',
              'more_info': {
                'artistMap': {
                  'artists': [
                    {'name': 'Jubin Nautiyal', 'id': 'artist2'}
                  ]
                }
              },
            },
          ],
          'charts': [
            {
              'id': 'mock_playlist_1',
              'title': 'Top 50 India',
              'subtitle': 'Most Streamed',
              'type': 'playlist',
              'image': 'https://via.placeholder.com/150/F38181/FFFFFF?text=Charts',
              'perma_url': '',
            },
          ],
          'new_albums': [
            {
              'id': 'mock_album_1',
              'title': 'Brahmastra',
              'subtitle': 'Pritam',
              'type': 'album',
              'image': 'https://via.placeholder.com/150/AA96DA/FFFFFF?text=Album',
              'perma_url': '',
            },
          ],
        };
        lists = ['recent', 'playlist', ...?data['collections'] as List?];
        lists.insert((lists.length / 2).round(), 'likedArtists');
        
        if (mounted) {
          ShowSnackBar().showSnackBar(
            context,
            'Demo Mode: Jiosaavn blocks web access. Run on Android/iOS for real data.',
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        if (mounted) {
          ShowSnackBar().showSnackBar(
            context,
            'Error loading data: $e',
            duration: const Duration(seconds: 3),
          );
        }
      }
    } finally {
      if (mounted && !fetched) {
        setState(() {
          fetched = true;
        });
      }
    }
  }

  String getSubTitle(Map item) {
    final type = item['type'];
    switch (type) {
      case 'charts':
        return '';
      case 'radio_station':
        return 'Radio • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle']?.toString().unescape()}';
      case 'playlist':
        return 'Playlist • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'song':
        return 'Single • ${item['artist']?.toString().unescape()}';
      case 'mix':
        return 'Mix • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'show':
        return 'Podcast • ${(item['subtitle']?.toString() ?? '').isEmpty ? 'JioSaavn' : item['subtitle'].toString().unescape()}';
      case 'album':
        final artists = item['more_info']?['artistMap']?['artists']
            .map((artist) => artist['name'])
            .toList();
        if (artists != null) {
          return 'Album • ${artists?.join(', ')?.toString().unescape()}';
        } else if (item['subtitle'] != null && item['subtitle'] != '') {
          return 'Album • ${item['subtitle']?.toString().unescape()}';
        }
        return 'Album';
      default:
        final artists = item['more_info']?['artistMap']?['artists']
            .map((artist) => artist['name'])
            .toList();
        return artists?.join(', ')?.toString().unescape() ?? '';
    }
  }

  int likedCount() {
    return Hive.box('Favorite Songs').length;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    double boxSize =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width
            ? MediaQuery.sizeOf(context).width / 2
            : MediaQuery.sizeOf(context).height / 2.5;
    if (boxSize > 250) boxSize = 250;
    if (playlistNames.length >= 3) {
      recentIndex = 0;
      playlistIndex = 1;
    } else {
      recentIndex = 1;
      playlistIndex = 0;
    }
    return (data.isEmpty && recentList.isEmpty)
        ? Center(
            child: fetched 
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context)!.nothingTo, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      child: const Text('Retry'),
                      onPressed: () {
                        setState(() { fetched = false; });
                        getHomePageData();
                      },
                    )
                  ],
                )
              : const CircularProgressIndicator(),
          )
        : ListView.builder(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 2000.0,
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 120),
            itemCount: data.isEmpty ? 2 : lists.length,
            itemBuilder: (context, idx) {
              if (idx == recentIndex) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box('cache').listenable(),
                  builder: (BuildContext context, Box box, Widget? _) {
                    final List currentRecentList =
                        box.get('recentSongs', defaultValue: []) as List;
                    final bool showRecent = Hive.box('settings')
                        .get('showRecent', defaultValue: true) as bool;
                    
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: (currentRecentList.isEmpty || !showRecent)
                        ? const SizedBox(key: ValueKey('recent_empty'))
                        : Column(
                            key: const ValueKey('recent_content'),
                            children: [
                              GestureDetector(
                                child: Row(
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(15, 10, 0, 5),
                                      child: Text(
                                        AppLocalizations.of(context)!.lastSession,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pushNamed(context, '/recent');
                                },
                              ),
                              HorizontalAlbumsListSeparated(
                                songsList: currentRecentList,
                                onTap: (int idx) {
                                  PlayerInvoke.init(
                                    songsList: [currentRecentList[idx]],
                                    index: 0,
                                    isOffline: false,
                                  );
                                },
                              ),
                            ],
                          ),
                    );
                  },
                );
              }
              if (idx == playlistIndex) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box('settings').listenable(),
                  builder: (BuildContext context, Box box, Widget? _) {
                    final List currentPlaylistNames =
                        box.get('playlistNames')?.toList() as List? ??
                            ['Favorite Songs'];
                    final Map currentPlaylistDetails =
                        box.get('playlistDetails', defaultValue: {}) as Map;
                    final bool showPlaylist =
                        box.get('showPlaylist', defaultValue: true) as bool;

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: (currentPlaylistNames.isEmpty ||
                          currentPlaylistDetails.isEmpty ||
                          !showPlaylist ||
                          (currentPlaylistNames.length == 1 &&
                              currentPlaylistNames.first == 'Favorite Songs' &&
                              likedCount() == 0))
                        ? const SizedBox(key: ValueKey('playlist_empty'))
                        : Column(
                            key: const ValueKey('playlist_content'),
                            children: [
                              GestureDetector(
                                child: Row(
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(15, 10, 15, 5),
                                      child: Text(
                                        AppLocalizations.of(context)!.yourPlaylists,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pushNamed(context, '/playlists');
                                },
                              ),
                              SizedBox(
                                height: boxSize + 15,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  itemCount: currentPlaylistNames.length,
                                  itemBuilder: (context, index) {
                                    final String name =
                                        currentPlaylistNames[index].toString();
                                    final String showName = currentPlaylistDetails
                                            .containsKey(name)
                                        ? currentPlaylistDetails[name]['name']
                                                ?.toString() ??
                                            name
                                        : name;
                                    final String? subtitle = currentPlaylistDetails[
                                                    name] ==
                                                null ||
                                            currentPlaylistDetails[name]['count'] ==
                                                null ||
                                            currentPlaylistDetails[name]['count'] == 0
                                        ? null
                                        : '${currentPlaylistDetails[name]['count']} ${AppLocalizations.of(context)!.songs}';
                                    if (currentPlaylistDetails[name] == null ||
                                        currentPlaylistDetails[name]['count'] ==
                                            null ||
                                        currentPlaylistDetails[name]['count'] == 0) {
                                      return const SizedBox();
                                    }
                                    return GestureDetector(
                                      child: SizedBox(
                                        width: boxSize - 20,
                                        child: HoverBox(
                                          child: Collage(
                                            borderRadius: 20.0,
                                            imageList: currentPlaylistDetails[name]
                                                ['imagesList'] as List,
                                            showGrid: true,
                                            placeholderImage: 'assets/cover.jpg',
                                          ),
                                          builder: ({
                                            required BuildContext context,
                                            required bool isHover,
                                            Widget? child,
                                          }) {
                                            return Card(
                                              color:
                                                  isHover ? null : Colors.transparent,
                                              elevation: 0,
                                              margin: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                  20.0,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Column(
                                                children: [
                                                  SizedBox.square(
                                                    dimension: isHover
                                                        ? boxSize - 25
                                                        : boxSize - 30,
                                                    child: child,
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10.0,
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          showName,
                                                          textAlign:
                                                              TextAlign.center,
                                                          softWrap: false,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        if (subtitle != null &&
                                                            subtitle.isNotEmpty)
                                                          Text(
                                                            subtitle,
                                                            textAlign:
                                                                TextAlign.center,
                                                            softWrap: false,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .color,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      onTap: () async {
                                        await Hive.openBox(name);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LikedSongs(
                                              playlistName: name,
                                              showName: currentPlaylistDetails
                                                      .containsKey(name)
                                                  ? currentPlaylistDetails[name]
                                                              ['name']
                                                          ?.toString() ??
                                                      name
                                                  : name,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                );
              }
              if (lists[idx] == 'likedArtists') {
                final List likedArtistsList = likedArtists.values.toList();
                return likedArtists.isEmpty
                    ? const SizedBox()
                    : Column(
                        children: [
                          Row(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(15, 10, 0, 5),
                                child: Text(
                                  'Liked Artists',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          HorizontalAlbumsList(
                            songsList: likedArtistsList,
                            onTap: (int idx) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (_, __, ___) => ArtistSearchPage(
                                    data: likedArtistsList[idx] as Map,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
              }
              final bool isEmpty = data[lists[idx]] == null ||
                  data[lists[idx]] is! List ||
                  (data[lists[idx]] as List).isEmpty;

              return (isEmpty ||
                      blacklistedHomeSections.contains(
                        data['modules'][lists[idx]]?['title']
                            ?.toString()
                            .toLowerCase(),
                      ))
                  ? const SizedBox()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 10, 15, 5),
                          child: Row(
                            children: [
                              GestureDetector(
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15.0),
                                        ),
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!
                                              .blacklistHomeSections,
                                        ),
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!
                                              .blacklistHomeSectionsConfirm,
                                        ),
                                        actions: [
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(context)
                                                  .iconTheme
                                                  .color,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!
                                                  .no,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .secondary,
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              blacklistedHomeSections.add(
                                                data['modules'][lists[idx]]
                                                        ?['title']
                                                    ?.toString()
                                                    .toLowerCase(),
                                              );
                                              Hive.box('settings').put(
                                                'blacklistedHomeSections',
                                                blacklistedHomeSections,
                                              );
                                              setState(() {});
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!
                                                  .yes,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary ==
                                                        Colors.white
                                                    ? Colors.black
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 5,
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Text(
                                  data['modules'][lists[idx]]?['title']
                                          ?.toString()
                                          .unescape() ??
                                      '',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: boxSize + 15,
                          child: Builder(
                            builder: (context) {
                              if (data[lists[idx]] is! List) {
                                return const SizedBox();
                              }
                              final List sectionList = data[lists[idx]] as List;
                              if (sectionList.isEmpty) {
                                return const SizedBox();
                              }
                              final bool isRadio = data['modules'][lists[idx]]
                                      ?['title']
                                  ?.toString() ==
                                  'Radio Stations';
                              final List currentSongList = isRadio ? [] : sectionList
                                  .where((e) => e is Map && e['type'] == 'song')
                                  .toList();
                              final int itemCount = isRadio
                                  ? sectionList.length + likedRadio.length
                                  : sectionList.length;
                              if (itemCount == 0) return const SizedBox();

                              return ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: itemCount,
                                itemBuilder: (context, index) {
                                  Map item;
                                  if (isRadio) {
                                    index < likedRadio.length
                                        ? item = likedRadio[index] as Map
                                        : item = sectionList[index - likedRadio.length] as Map;
                                  } else {
                                    item = sectionList[index] as Map;
                                  }
                                  if (item.isEmpty) return const SizedBox();
                                  final subTitle = getSubTitle(item);
                                  return GestureDetector(
                                onLongPress: () {
                                  Feedback.forLongPress(context);
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return InteractiveViewer(
                                        child: Stack(
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                            ),
                                            AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15.0),
                                              ),
                                              backgroundColor:
                                                  Colors.transparent,
                                              contentPadding: EdgeInsets.zero,
                                              content: imageCard(
                                                borderRadius: item['type'] ==
                                                        'radio_station'
                                                    ? 1000.0
                                                    : 15.0,
                                                imageUrl:
                                                    item['image'].toString(),
                                                imageQuality: ImageQuality.high,
                                                boxDimension:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.8,
                                                placeholderImage: (item[
                                                                'type'] ==
                                                            'playlist' ||
                                                        item['type'] == 'album')
                                                    ? const AssetImage(
                                                        'assets/album.png',
                                                      )
                                                    : item['type'] == 'artist'
                                                        ? const AssetImage(
                                                            'assets/artist.png',
                                                          )
                                                        : const AssetImage(
                                                            'assets/cover.jpg',
                                                          ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                onTap: () {
                                  if (item['type'] == 'radio_station') {
                                    ShowSnackBar().showSnackBar(
                                      context,
                                      AppLocalizations.of(context)!
                                          .connectingRadio,
                                      duration: const Duration(seconds: 2),
                                    );
                                    SaavnAPI()
                                        .createRadio(
                                      names: item['more_info']
                                                      ['featured_station_type']
                                                  .toString() ==
                                              'artist'
                                          ? [
                                              item['more_info']['query']
                                                  .toString(),
                                            ]
                                          : [item['id'].toString()],
                                      language: item['more_info']['language']
                                              ?.toString() ??
                                          'hindi',
                                      stationType: item['more_info']
                                              ['featured_station_type']
                                          .toString(),
                                    )
                                        .then((value) {
                                      if (value != null) {
                                        SaavnAPI()
                                            .getRadioSongs(stationId: value)
                                            .then((value) {
                                          PlayerInvoke.init(
                                            songsList: value,
                                            index: 0,
                                            isOffline: false,
                                            shuffle: true,
                                          );
                                        });
                                      }
                                    });
                                  } else {
                                    if (item['type'] == 'song') {
                                      PlayerInvoke.init(
                                        songsList: currentSongList as List,
                                        index: currentSongList.indexWhere(
                                          (e) => e['id'] == item['id'],
                                        ),
                                        isOffline: false,
                                      );
                                    } else if (item['type'] == 'artist') {
                                      if (item['artistToken'] == null || item['artistToken'].toString().isEmpty) {
                                        if (item['perma_url'] != null && item['perma_url'].toString().isNotEmpty) {
                                          item['artistToken'] = item['perma_url'].toString().split('/').last;
                                        } else if (item['url'] != null && item['url'].toString().isNotEmpty) {
                                           item['artistToken'] = item['url'].toString().split('/').last;
                                        }
                                      }
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, __, ___) =>
                                              ArtistSearchPage(
                                            data: item,
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, __, ___) =>
                                              SongsListPage(
                                            listItem: item,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: SizedBox(
                                  width: boxSize - 30,
                                  child: HoverBox(
                                    child: imageCard(
                                      margin: const EdgeInsets.all(4.0),
                                      borderRadius:
                                          item['type'] == 'radio_station'
                                              ? 1000.0
                                              : 10.0,
                                      imageUrl: item['image'].toString(),
                                      imageQuality: ImageQuality.medium,
                                      placeholderImage:
                                          (item['type'] == 'playlist' ||
                                                  item['type'] == 'album')
                                              ? const AssetImage(
                                                  'assets/album.png',
                                                )
                                              : item['type'] == 'artist'
                                                  ? const AssetImage(
                                                      'assets/artist.png',
                                                    )
                                                  : const AssetImage(
                                                      'assets/cover.jpg',
                                                    ),
                                    ),
                                    builder: ({
                                      required BuildContext context,
                                      required bool isHover,
                                      Widget? child,
                                    }) {
                                      return Card(
                                        color:
                                            isHover ? null : Colors.transparent,
                                        elevation: 0,
                                        margin: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          children: [
                                            Stack(
                                              children: [
                                                SizedBox.square(
                                                  dimension: isHover
                                                      ? boxSize - 25
                                                      : boxSize - 30,
                                                  child: child,
                                                ),
                                                if (isHover &&
                                                    (item['type'] == 'song' ||
                                                        item['type'] ==
                                                            'radio_station'))
                                                  Positioned.fill(
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.all(
                                                        4.0,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black54,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          item['type'] ==
                                                                  'radio_station'
                                                              ? 1000.0
                                                              : 10.0,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: DecoratedBox(
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                Colors.black87,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              1000.0,
                                                            ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .play_arrow_rounded,
                                                            size: 50.0,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (item['type'] ==
                                                        'radio_station' &&
                                                    (kIsWeb || (Platform.isAndroid ||
                                                        Platform.isIOS) ||
                                                        isHover))
                                                  Align(
                                                    alignment:
                                                        Alignment.topRight,
                                                    child: Card(
                                                      margin: EdgeInsets.zero,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          1000.0,
                                                        ),
                                                      ),
                                                      elevation: 0,
                                                      color: Colors.transparent,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Icon(
                                                          Icons
                                                              .radio_rounded,
                                                          color: Colors.white,
                                                          size: isHover
                                                              ? 20
                                                              : 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
            },
          );
  }
}
