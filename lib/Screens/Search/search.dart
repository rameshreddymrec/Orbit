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
import 'package:orbit/CustomWidgets/download_button.dart';
import 'package:orbit/CustomWidgets/empty_screen.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/image_card.dart';
import 'package:orbit/CustomWidgets/like_button.dart';
import 'package:orbit/CustomWidgets/media_tile.dart';
import 'package:orbit/CustomWidgets/search_bar.dart' as searchbar;
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/CustomWidgets/song_tile_trailing_menu.dart';
import 'package:orbit/Screens/Common/song_list.dart';
import 'package:orbit/Screens/Search/albums.dart';
import 'package:orbit/Screens/Search/artists.dart';

import 'package:orbit/Services/player_service.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

class SearchPage extends StatefulWidget {
  final String query;
  final bool fromHome;
  final bool fromDirectSearch;
  final String? searchType;
  final bool autofocus;
  const SearchPage({
    super.key,
    required this.query,
    this.fromHome = false,
    this.fromDirectSearch = false,
    this.searchType,
    this.autofocus = false,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  bool fetchResultCalled = false;
  bool fetched = false;
  bool alertShown = false;
  bool? fromHome;
  List<Map<dynamic, dynamic>> searchedList = [];
  String searchType = 'saavn';
  List searchHistory =
      Hive.box('settings').get('search', defaultValue: []) as List;
  bool liveSearch =
      Hive.box('settings').get('liveSearch', defaultValue: true) as bool;
  final ValueNotifier<List<String>> topSearch = ValueNotifier<List<String>>(
    [],
  );

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    _controller.text = widget.query;
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchResults() async {
    Logger.root.info(
      'fetching search results for ${query == '' ? widget.query : query}',
    );
    searchedList = await SaavnAPI()
        .fetchSearchResults(query == '' ? widget.query : query);
    for (final element in searchedList) {
      if (element['title'] != 'Top Result') {
        element['allowViewAll'] = true;
      }
    }
    setState(() {
      fetched = true;
    });
  }

  Future<void> getTrendingSearch() async {
    topSearch.value = await SaavnAPI().getTopSearches();
  }

  void addToHistory(String title) {
    final tempquery = title.trim();
    if (tempquery == '') {
      return;
    }
    final idx = searchHistory.indexOf(tempquery);
    if (idx != -1) {
      searchHistory.removeAt(idx);
    }
    searchHistory.insert(
      0,
      tempquery,
    );
    if (searchHistory.length > 10) {
      searchHistory = searchHistory.sublist(0, 10);
    }
    Hive.box('settings').put(
      'search',
      searchHistory,
    );
  }

  Widget nothingFound(BuildContext context) {
    if (!alertShown) {
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.useVpn,
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          textColor: Theme.of(context).colorScheme.secondary,
          label: AppLocalizations.of(context)!.useProxy,
          onPressed: () {
            setState(() {
              Hive.box('settings').put('useProxy', true);
              fetched = false;
              fetchResultCalled = false;
              searchedList = [];
            });
          },
        ),
      );
      alertShown = true;
    }
    return emptyScreen(
      context,
      0,
      ':( ',
      100,
      AppLocalizations.of(context)!.sorry,
      60,
      AppLocalizations.of(context)!.resultsNotFound,
      20,
    );
  }

  @override
  Widget build(BuildContext context) {
    fromHome ??= widget.fromHome;
    if (!fetchResultCalled) {
      fetchResultCalled = true;
      fromHome! ? getTrendingSearch() : fetchResults();
    }
    return GradientContainer(
      child: SafeArea(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: searchbar.SearchBar(
            controller: _controller,
            liveSearch: liveSearch,
            autofocus: widget.autofocus,
            hintText: AppLocalizations.of(context)!.searchText,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.chevron_back),
              onPressed: () {
                if ((fromHome ?? false) || widget.fromDirectSearch) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    fromHome = true;
                    _controller.text = '';
                  });
                }
              },
            ),
            body: (fromHome!)
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5.0,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 65),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Wrap(
                            children: List<Widget>.generate(
                              searchHistory.length,
                              (int index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5.0,
                                    vertical: 5.0,
                                  ),
                                  child: GestureDetector(
                                    child: Chip(
                                      label: Text(
                                        searchHistory[index].toString(),
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          searchHistory.removeAt(index);
                                          Hive.box('settings').put(
                                            'search',
                                            searchHistory,
                                          );
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        fetched = false;
                                        query = searchHistory
                                            .removeAt(index)
                                            .toString()
                                            .trim();
                                        addToHistory(query);
                                        _controller.text = query;
                                        _controller.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(offset: query.length),
                                        );
                                        fetchResultCalled = false;
                                        fromHome = false;
                                        searchedList = [];
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: topSearch,
                          builder: (context, List<String> value, child) {
                            if (value.isEmpty) return const SizedBox();
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!
                                            .trendingSearch,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Wrap(
                                    children: List<Widget>.generate(
                                      value.length,
                                      (int index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0, vertical: 5.0),
                                          child: ChoiceChip(
                                            label: Text(value[index]),
                                            selected: false,
                                            onSelected: (bool selected) {
                                              if (selected) {
                                                setState(() {
                                                  fetched = false;
                                                  query = value[index].trim();
                                                  _controller.text = query;
                                                  _controller.selection =
                                                      TextSelection.fromPosition(
                                                    TextPosition(
                                                        offset: query.length),
                                                  );
                                                  addToHistory(query);
                                                  fetchResultCalled = false;
                                                  fromHome = false;
                                                  searchedList = [];
                                                });
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 50),
                      Expanded(
                        child: !fetched
                            ? const Center(child: CircularProgressIndicator())
                            : (searchedList.isEmpty)
                                ? nothingFound(context)
                                : CustomScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    
                                    slivers: [
                                      for (final Map section in searchedList) ...[
                                        if (section['items'] != null &&
                                            (section['items'] as List)
                                                .isNotEmpty) ...[
                                          SliverToBoxAdapter(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 17,
                                                right: 15,
                                                top: 15,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    section['title'].toString(),
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .secondary,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  if (section['allowViewAll'] ==
                                                      true)
                                                    GestureDetector(
                                                      onTap: () {
                                                        final String title =
                                                            section['title']
                                                                .toString();
                                                        if (title == 'Albums' ||
                                                            title == 'Playlists' ||
                                                            title ==
                                                                'Artists') {
                                                          Navigator.push(
                                                            context,
                                                            PageRouteBuilder(
                                                              opaque: false,
                                                              pageBuilder:
                                                                  (_, __, ___) =>
                                                                      AlbumSearchPage(
                                                                query: query == ''
                                                                    ? widget
                                                                        .query
                                                                    : query,
                                                                type: title,
                                                              ),
                                                            ),
                                                          );
                                                        } else if (title ==
                                                            'Songs') {
                                                          Navigator.push(
                                                            context,
                                                            PageRouteBuilder(
                                                              opaque: false,
                                                              pageBuilder:
                                                                  (_, __, ___) =>
                                                                      SongsListPage(
                                                                listItem: {
                                                                  'id': query == ''
                                                                      ? widget
                                                                          .query
                                                                      : query,
                                                                  'title': title,
                                                                  'type': 'songs',
                                                                },
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .viewAll,
                                                            style: TextStyle(
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .color,
                                                              fontWeight:
                                                                  FontWeight.w800,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .chevron_right_rounded,
                                                            color: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall!
                                                                .color,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SliverPadding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5),
                                            sliver: SliverList(
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                (context, index) {
                                                  final List items =
                                                      section['items'] as List;
                                                  final String title =
                                                      section['title']
                                                          .toString();
                                                  final int count = items[index]
                                                          ['count'] as int? ??
                                                      0;
                                                  final itemType = items[index]
                                                                  ['type']
                                                              ?.toString()
                                                              .toLowerCase() ??
                                                      'video';
                                                  String countText = '';
                                                  if (count >= 1) {
                                                    countText = count > 1
                                                        ? '$count ${AppLocalizations.of(context)!.songs}'
                                                        : '$count ${AppLocalizations.of(context)!.song}';
                                                  }
                                                  return MediaTile(
                                                    title: items[index]['title']
                                                        .toString(),
                                                    subtitle: countText != ''
                                                        ? '$countText\n${items[index]["subtitle"]}'
                                                        : items[index]
                                                                ['subtitle']
                                                            .toString(),
                                                    isThreeLine:
                                                        countText != '',
                                                    leadingWidget: imageCard(
                                                      borderRadius:
                                                          title == 'Artists' ||
                                                                  itemType ==
                                                                      'artist'
                                                              ? 50.0
                                                              : 7.0,
                                                      placeholderImage: AssetImage(
                                                        title == 'Artists' ||
                                                                itemType ==
                                                                    'artist'
                                                            ? 'assets/artist.png'
                                                            : title == 'Songs'
                                                                ? 'assets/cover.jpg'
                                                                : 'assets/album.png',
                                                      ),
                                                      imageUrl: items[index]
                                                              ['image']
                                                          .toString(),
                                                    ),
                                                    trailingWidget: title !=
                                                            'Albums'
                                                        ? title == 'Songs'
                                                            ? Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  DownloadButton(
                                                                    data: items[
                                                                            index]
                                                                        as Map,
                                                                    icon:
                                                                        'download',
                                                                  ),
                                                                  LikeButton(
                                                                    mediaItem:
                                                                        null,
                                                                    data: items[
                                                                            index]
                                                                        as Map,
                                                                  ),
                                                                  SongTileTrailingMenu(
                                                                    data: items[
                                                                            index]
                                                                        as Map,
                                                                  ),
                                                                ],
                                                              )
                                                            : null
                                                        : AlbumDownloadButton(
                                                            albumName: items[
                                                                    index]
                                                                    ['title']
                                                                .toString(),
                                                            albumId: items[
                                                                    index]['id']
                                                                .toString(),
                                                          ),
                                                    onTap: () {
                                                      if (title == 'Songs' ||
                                                          (title == 'Top Result' &&
                                                              items[0]
                                                                      ['type'] ==
                                                                  'song')) {
                                                        PlayerInvoke.init(
                                                          songsList: items,
                                                          index: index,
                                                          isOffline: false,
                                                        );
                                                      } else {
                                                        Navigator.push(
                                                          context,
                                                          PageRouteBuilder(
                                                            opaque: false,
                                                            pageBuilder:
                                                                (_, __, ___) =>
                                                                    itemType ==
                                                                            'artist' ||
                                                                        title ==
                                                                            'Artists' ||
                                                                        (title ==
                                                                                'Top Result' &&
                                                                            items[0]
                                                                                    [
                                                                                    'type'] ==
                                                                                'artist')
                                                                    ? ArtistSearchPage(
                                                                        data: items[
                                                                                index]
                                                                            as Map,
                                                                      )
                                                                    : SongsListPage(
                                                                        listItem:
                                                                            items[index]
                                                                                as Map,
                                                                      ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  );
                                                },
                                                childCount:
                                                    (section['items'] as List)
                                                        .length,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                      ),
                    ],
                  ),
            onSubmitted: (String submittedQuery) {
              setState(() {
                fetched = false;
                fromHome = false;
                fetchResultCalled = false;
                query = submittedQuery;
                _controller.text = submittedQuery;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: query.length),
                );
                searchedList = [];
              });
            },
            onQueryChanged: (changedQuery) {
              return SaavnAPI().getAutoSuggestions(changedQuery);
            },
          ),
        ),
      ),
    );
  }
}
