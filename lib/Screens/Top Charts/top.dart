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

import 'package:app_links/app_links.dart';
import 'package:orbit/APIs/api.dart';
import 'package:orbit/APIs/spotify_api.dart';
import 'package:orbit/CustomWidgets/custom_physics.dart';
import 'package:orbit/CustomWidgets/drawer.dart';
import 'package:orbit/CustomWidgets/empty_screen.dart';
import 'package:orbit/CustomWidgets/image_card.dart';
import 'package:orbit/Helpers/spotify_country.dart';
import 'package:orbit/Helpers/spotify_helper.dart';
// import 'package:orbit/Helpers/countrycodes.dart';
import 'package:orbit/Screens/Search/search.dart';
import 'package:orbit/constants/countrycodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

List localSongs = [];
List globalSongs = [];
bool localFetched = false;
bool globalFetched = false;
final ValueNotifier<bool> localFetchFinished = ValueNotifier<bool>(false);
final ValueNotifier<bool> globalFetchFinished = ValueNotifier<bool>(false);

class TopCharts extends StatefulWidget {
  final PageController pageController;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const TopCharts({super.key, required this.pageController, this.scaffoldKey});

  @override
  _TopChartsState createState() => _TopChartsState();
}

class _TopChartsState extends State<TopCharts>
    with AutomaticKeepAliveClientMixin<TopCharts> {
  final ValueNotifier<bool> localFetchFinished = ValueNotifier<bool>(false);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext cntxt) {
    super.build(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool rotated = MediaQuery.sizeOf(context).height < screenWidth;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          actions: const [],
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                child: Text(
                  AppLocalizations.of(context)!.local,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
              Tab(
                child: Text(
                  AppLocalizations.of(context)!.global,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            AppLocalizations.of(context)!.spotifyCharts,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: rotated ? null : homeDrawer(context: context, scaffoldKey: widget.scaffoldKey),
        ),
        body: NotificationListener(
          onNotification: (overscroll) {
            if (overscroll is OverscrollNotification &&
                overscroll.overscroll != 0 &&
                overscroll.dragDetails != null) {
              widget.pageController.animateToPage(
                overscroll.overscroll < 0 ? 0 : 2,
                curve: Curves.ease,
                duration: const Duration(milliseconds: 150),
              );
            }
            return true;
          },
          child: TabBarView(
            physics: const CustomPhysics(),
            children: [
              ValueListenableBuilder(
                valueListenable: Hive.box('settings').listenable(),
                builder: (BuildContext context, Box box, Widget? widget) {
                  return TopPage(
                    type: box.get('region', defaultValue: 'India').toString(),
                  );
                },
              ),
              // TopPage(type: 'local'),
              const TopPage(type: 'Global'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List> getChartDetails(String accessToken, String type) async {
  final String globalPlaylistId = CountryCodes.localChartCodes['Global']!;
  final String localPlaylistId = CountryCodes.localChartCodes.containsKey(type)
      ? CountryCodes.localChartCodes[type]!
      : CountryCodes.localChartCodes['India']!;
  final String playlistId =
      type == 'Global' ? globalPlaylistId : localPlaylistId;
  final List data = [];
  final List tracks =
      await SpotifyApi().getAllTracksOfPlaylist(accessToken, playlistId);
  for (final track in tracks) {
    final trackName = track['track']['name'];
    final imageUrlSmall = track['track']['album']['images'].last['url'];
    final imageUrlBig = track['track']['album']['images'].first['url'];
    final spotifyUrl = track['track']['external_urls']['spotify'];
    final artistName = track['track']['artists'][0]['name'].toString();
    data.add({
      'name': trackName,
      'artist': artistName,
      'image_url_small': imageUrlSmall,
      'image_url_big': imageUrlBig,
      'spotifyUrl': spotifyUrl,
    });
  }
  return data;
}

Future<void> scrapData(String type, {bool signIn = false}) async {
  bool spotifySigned =
      Hive.box('settings').get('spotifySigned', defaultValue: false) as bool;
  final String? accessToken = await retriveAccessToken();

  if (spotifySigned && accessToken != null && !signIn) {
    try {
      final temp = await getChartDetails(accessToken, type);
      if (temp.isNotEmpty) {
        Hive.box('cache').put('${type}_chart', temp);
        if (type == 'Global') {
          globalSongs = temp;
          globalFetchFinished.value = true;
        } else {
          localSongs = temp;
          localFetchFinished.value = true;
        }
        return; // Success with Spotify
      }
    } catch (e) {
      Logger.root.severe('Error fetching Spotify charts: $e');
    }
  }

  // Fallback to Saavn Charts (if Spotify not signed, or failed, or empty)
  if (!signIn) {
    try {
      // Improvements for Global (Search-based logic)
      if (type == 'Global') {
        String query = 'International Top 50';
        print('DEBUG: Searching for Global charts with query: $query');
        
        List<Map> searchResults = await SaavnAPI().fetchAlbums(
          searchQuery: query, 
          type: 'playlist',
        );

        // Fallbacks for Global
        if (searchResults.isEmpty) {
          print('DEBUG: Global search failed, trying fallback: Global Top 50');
          searchResults = await SaavnAPI().fetchAlbums(
            searchQuery: 'Global Top 50', 
            type: 'playlist',
          );
        }
        if (searchResults.isEmpty) {
           print('DEBUG: Global search failed, trying fallback: English Top 50');
          searchResults = await SaavnAPI().fetchAlbums(
            searchQuery: 'English Top 50', 
            type: 'playlist',
          );
        }

        if (searchResults.isNotEmpty) {
            print('DEBUG: Found Global playlist: ${searchResults[0]['title']} (${searchResults[0]['id']})');
            final String playlistId = searchResults[0]['id'].toString();
            final Map playlistData =
                await SaavnAPI().fetchPlaylistSongs(playlistId);
            final List songs = playlistData['songs'] as List? ?? [];

            final List formattedSongs = songs.map((s) => {
                  'name': s['title'],
                  'artist': s['artist'],
                  'image_url_small': s['image'],
                  'image_url_big': s['image'],
                  'spotifyUrl': s['perma_url'],
                  'id': s['id'],
                  'perma_url': s['perma_url'],
                  'url': s['url'],
                }).toList();

            if (formattedSongs.isNotEmpty) {
                globalSongs = formattedSongs;
                globalFetchFinished.value = true;
                Hive.box('cache').put('${type}_chart', formattedSongs);
                return;
            }
        }
      }

      // Exact Code from Snippet for Local (Home Page Data)
      final Map homeData = await SaavnAPI().fetchHomePageData();
      final List charts = homeData['charts'] as List? ?? [];
      if (charts.isNotEmpty) {
        final String playlistId = charts[0]['id'].toString();
        final Map playlistData =
            await SaavnAPI().fetchPlaylistSongs(playlistId);
        final List songs = playlistData['songs'] as List? ?? [];

        final List formattedSongs = songs
            .map((s) => {
                  'name': s['title'],
                  'artist': s['artist'],
                  'image_url_small': s['image'],
                  'image_url_big': s['image'],
                  'spotifyUrl': s['perma_url'],
                  'id': s['id'],
                  'perma_url': s['perma_url'],
                  'url': s['url'],
                })
            .toList();

        if (formattedSongs.isNotEmpty) {
          if (type == 'Global') {
            globalSongs = formattedSongs;
            globalFetchFinished.value = true;
          } else {
            localSongs = formattedSongs;
            localFetchFinished.value = true;
          }
          // Added cache put (essential for persistence)
          Hive.box('cache').put('${type}_chart', formattedSongs);
          return;
        }
      }
    } catch (e) {
      Logger.root.severe('Error fetching Saavn charts: $e');
    }
  }
}

class TopPage extends StatefulWidget {
  final String type;
  const TopPage({super.key, required this.type});
  @override
  _TopPageState createState() => _TopPageState();
}

class _TopPageState extends State<TopPage>
    with AutomaticKeepAliveClientMixin<TopPage> {
  Future<void> getCachedData(String type) async {
    if (type == 'Global') {
      globalFetched = true;
    } else {
      localFetched = true;
    }
    if (type == 'Global') {
      globalSongs = await Hive.box('cache')
          .get('${type}_chart', defaultValue: []) as List;
    } else {
      localSongs = await Hive.box('cache')
          .get('${type}_chart', defaultValue: []) as List;
    }
    setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Load cache immediately for instant UI
    getCachedData(widget.type);
    
    scrapData(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isGlobal = widget.type == 'Global';
    // if ((isGlobal && !globalFetched) || (!isGlobal && !localFetched)) {
    //   getCachedData(widget.type);
    //   scrapData(widget.type);
    // }
    return ValueListenableBuilder(
      valueListenable: isGlobal ? globalFetchFinished : localFetchFinished,
      builder: (BuildContext context, bool value, Widget? child) {
        final List showList = isGlobal ? globalSongs : localSongs;
        return Column(
          children: [

            if (!(Hive.box('settings').get('spotifySigned', defaultValue: false)
                as bool) && showList.isEmpty && !value)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (showList.isEmpty)
              Expanded(
                child: value
                    ? emptyScreen(
                        context,
                        0,
                        ':( ',
                        100,
                        'ERROR',
                        60,
                        'Service Unavailable',
                        20,
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                        ],
                      ),
              )
            else
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: showList.length,
                  itemExtent: 70.0,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: imageCard(
                        imageUrl: showList[index]['image_url_small'].toString(),
                      ),
                      title: Text(
                        '${index + 1}. ${showList[index]["name"]}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        showList[index]['artist'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(15.0),
                          ),
                        ),
                        onSelected: (int? value) async {
                          if (value == 0) {
                            await launchUrl(
                              Uri.parse(
                                showList[index]['spotifyUrl'].toString(),
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 0,
                            child: Row(
                              children: [
                                const Icon(Icons.open_in_new_rounded),
                                const SizedBox(width: 10.0),
                                Text(
                                  AppLocalizations.of(context)!.openInSpotify,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchPage(
                              query:
                                  '${showList[index]["name"]} - ${showList[index]["artist"]}',
                              fromDirectSearch: true,
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
