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

import 'dart:convert';

import 'package:orbit/Helpers/extensions.dart';
import 'package:orbit/Helpers/format.dart';
import 'package:orbit/constants/countrycodes.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class SaavnAPI {
  static final Map<String, Response> _cache = {};
  static final Map<String, dynamic> _resultCache = {};
  static final Map<String, dynamic> _metadataCache = {};

  List preferredLanguages = Hive.box('settings')
      .get('preferredLanguage', defaultValue: ['Hindi']) as List;
  Map<String, String> headers = {};
  String baseUrl = 'www.jiosaavn.com';
  String apiStr = '/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0';
  Box settingsBox = Hive.box('settings');
  Map<String, String> endpoints = {
    'homeData': '__call=webapi.getLaunchData',
    'topSearches': '__call=content.getTopSearches',
    'fromToken': '__call=webapi.get',
    'featuredRadio': '__call=webradio.createFeaturedStation',
    'artistRadio': '__call=webradio.createArtistStation',
    'entityRadio': '__call=webradio.createEntityStation',
    'radioSongs': '__call=webradio.getSong',
    'songDetails': '__call=song.getDetails',
    'playlistDetails': '__call=playlist.getDetails',
    'albumDetails': '__call=content.getAlbumDetails',
    'getReco': '__call=reco.getreco',
    'artistDetails': '__call=artist.getDetails',
    'searchAll': '__call=autocomplete.get',
    'getResults': '__call=search.getResults',
    'playlistResults': '__call=search.getPlaylistResults',
    'albumResults': '__call=search.getAlbumResults',
    'artistResults': '__call=search.getArtistResults',
  };

  Future<Response> getResponse(
    String params, {
    bool usev4 = true,
    bool useProxy = true,
    String? cc,
  }) async {
    Uri url;
    if (!usev4) {
      url = Uri.https(
        baseUrl,
        '$apiStr&$params'.replaceAll('&api_version=4', ''),
      );
    } else {
      url = Uri.https(baseUrl, '$apiStr&$params');
    }
    preferredLanguages =
        preferredLanguages.map((lang) => lang.toLowerCase()).toList();
    final String languageHeader = 'L=${preferredLanguages.join('%2C')}';
    
    final String cleanParams = params.startsWith('&') ? params.substring(1) : params;
    
    // Replace cc=in with the provided cc if applicable, or keep default
    // Note: apiStr contains 'ctx=web6dot0', but usually cc is separate. 
    // If not present in apiStr, we should append it or rely on headers?
    // Actually, usually Saavn infers from IP or accepts 'cc' param.
    // Let's explicitly add/replace 'cc' in the URL query parameters.
    
    String finalUrl = 'https://$baseUrl$apiStr&$cleanParams';
    if (!usev4) {
      finalUrl = finalUrl.replaceAll('&api_version=4', '');
    }
    
    // If a country code is provided, append it or replace existing
    if (cc != null) {
      if (finalUrl.contains('cc=')) {
        finalUrl = finalUrl.replaceAll(RegExp(r'cc=[^&]+'), 'cc=$cc');
      } else {
        finalUrl += '&cc=$cc';
      }
    }

    url = Uri.parse(finalUrl);
    
    headers = {
      'cookie': '$languageHeader; geo=$cc', // Try passing geo in cookie as well
      'Accept': '*/*',
    };

    if (useProxy && settingsBox.get('useProxy', defaultValue: false) as bool) {
      final String proxyIP =
          settingsBox.get('proxyIp', defaultValue: '103.47.67.134').toString();
      final proxyHeaders = headers;
      proxyHeaders['X-FORWARDED-FOR'] = proxyIP;
      return get(url, headers: proxyHeaders).onError((error, stackTrace) {
        return Response(
          {
            'status': 'failure',
            'error': error.toString(),
          }.toString(),
          404,
        );
      });
    }

    if (kIsWeb) {
      print('DEBUG: Original URL: $url');
      final String host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      url = Uri.parse('http://$host:3000/api/jiosaavn?url=${Uri.encodeComponent(url.toString())}');
      print('DEBUG: Proxy URL: $url');
    }

    if (_cache.containsKey(url.toString())) {
      return _cache[url.toString()]!;
    }

    print('DEBUG: Fetching $url');
    return get(url, headers: headers).then((response) {
       if (response.statusCode == 200) {
         _cache[url.toString()] = response;
       }
       return response;
    }).onError((error, stackTrace) {
      print('ERROR: Network error: $error\n$stackTrace');
      return Response(
        '{"error": "Network Error"}',
        500,
        headers: headers,
      );
    });
  }

  Future<Map> fetchHomePageData({String? language}) async {
    Map result = {};
    try {
      final String region = settingsBox.get('region', defaultValue: 'India') as String;
      String? cc = language ?? CountryCodes.countryCodes[region];
      
      // If Hindi is preferred, prioritize India region for better content
      if (preferredLanguages.contains('hindi') || preferredLanguages.contains('hi')) {
        cc = 'in';
      }

      final res = await getResponse(
        endpoints['homeData']!,
        useProxy: false,
        cc: cc,
      );
      if (res.statusCode == 200) {
        Map data = {};
        try {
          data = await compute(jsonDecode, res.body) as Map;
        } catch (e) {
          Logger.root.severe('Error decoding JSON in fetchHomePageData: $e');
          data = jsonDecode(res.body) as Map;
        }
        Logger.root.info('Home Launch Data Keys: ${data.keys.toList()}');
        if (data['modules'] != null && data['modules'] is Map) {
          (data['modules'] as Map).forEach((k, v) {
             Logger.root.info('Module Key: $k, Title: ${v['title']}');
          });
        }
        result = await FormatResponse.formatHomePageData(data);
      }
    } catch (e) {
      Logger.root.severe('Error in fetchHomePageData: $e');
    }
    return result;
  }

  Future<Map> getSongFromToken(
    String token,
    String type, {
    int n = 10,
    int p = 1,
  }) async {
    if (n == -1) {
      // loop through until all songs are fetch
      final String params =
          "token=$token&type=$type&n=5&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = await compute(jsonDecode, res.body) as Map;
          final String count = getMain['list_count'].toString();
          final String params2 =
              "token=$token&type=$type&n=$count&p=$p&${endpoints['fromToken']}";
          final res2 = await getResponse(params2);
          if (res2.statusCode == 200) {
            final Map getMain2 = await compute(jsonDecode, res2.body) as Map;
            final List responseList = ((type == 'album' || type == 'playlist')
                ? getMain2['list']
                : getMain2['songs']) as List;
            final result = {
              'songs':
                  await FormatResponse.formatSongsInList(responseList),
              'title': getMain2['title'],
            };
            return result;
          } else {
            Logger.root.severe(
              'getSongFromToken with -1 got res2 with ${res2.statusCode}: ${res2.body}',
            );
          }
        } else {
          Logger.root.severe(
            'getSongFromToken with -1 got ${res.statusCode}: ${res.body}',
          );
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken with -1: $e');
      }
      return {'songs': List.empty()};
    } else {
      final String params =
          "token=$token&type=$type&n=$n&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = await compute(jsonDecode, res.body) as Map;
          if (getMain['status'] == 'failure') {
            Logger.root.severe('Error in getSongFromToken response: $getMain');
            return {'songs': List.empty()};
          }
          if (type == 'album' || type == 'playlist') {
            return getMain;
          }
          if (type == 'show') {
            final List responseList = getMain['episodes'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsInList(responseList),
            };
          }
          if (type == 'mix') {
            final List responseList = getMain['list'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsInList(responseList),
            };
          }
          final List responseList = getMain['songs'] as List;
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, type),
            'title': getMain['title'],
          };
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken: $e');
      }
      return {'songs': List.empty()};
    }
  }

  Future<List> getReco(String pid) async {
    final String params = "${endpoints['getReco']}&pid=$pid";
    final res = await getResponse(params);
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final List getMain = json.decode(res.body) as List;
      return FormatResponse.formatSongsInList(getMain);
    } else {
      Logger.root.severe(
        'Error in getReco returned status: ${res.statusCode}, response: ${res.body}',
      );
    }
    return List.empty();
  }

  Future<String?> createRadio({
    required List<String> names,
    required String stationType,
    String? language,
  }) async {
    String? params;
    if (stationType == 'featured') {
      params =
          "name=${names[0]}&language=$language&${endpoints['featuredRadio']}";
    }
    if (stationType == 'artist') {
      params =
          "name=${names[0]}&query=${names[0]}&language=$language&${endpoints['artistRadio']}";
    }
    if (stationType == 'entity') {
      params =
          'entity_id=${names.map((e) => '"$e"').toList()}&entity_type=queue&${endpoints["entityRadio"]}';
    }

    final res = await getResponse(params!);
    if (res.statusCode == 200) {
      final Map getMain = json.decode(res.body) as Map;
      return getMain['stationid']?.toString();
    }
    return null;
  }

  Future<List> getRadioSongs({
    required String stationId,
    int count = 20,
    int next = 1,
  }) async {
    if (count > 0) {
      final String params =
          "stationid=$stationId&k=$count&next=$next&${endpoints['radioSongs']}";
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final Map getMain = json.decode(res.body) as Map;
        final List responseList = [];
        if (getMain['error'] != null && getMain['error'] != '') {
          return [];
        }
        for (int i = 0; i < count; i++) {
          responseList.add(getMain[i.toString()]['song']);
        }
        return FormatResponse.formatSongsInList(responseList);
      }
      return [];
    }
    return [];
  }

  Future<List<String>> getTopSearches() async {
    try {
      final res = await getResponse(endpoints['topSearches']!);
      if (res.statusCode == 200) {
        final List getMain = json.decode(res.body) as List;
        return getMain.map((element) {
          return element['title'].toString();
        }).toList();
      }
    } catch (e) {
      Logger.root.severe('Error in getTopSearches: $e');
    }
    return List.empty();
  }

  Future<Map> fetchSongSearchResults({
    required String searchQuery,
    int count = 20,
    int page = 1,
  }) async {
    final String cacheKey = 'song_search_${searchQuery}_${count}_$page';
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey] as Map;
    }
    final String params =
        'p=$page&q=$searchQuery&n=$count&${endpoints["getResults"]}';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final Map getMain = json.decode(res.body) as Map;
        final List responseList = getMain['results'] as List;
        final finalSongs =
            await FormatResponse.formatSongsInList(responseList);
        if (finalSongs.length > count) {
          finalSongs.removeRange(count, finalSongs.length);
        }
        final result = {
          'songs': finalSongs,
          'error': '',
        };
        _resultCache[cacheKey] = result;
        return result;
      } else {
        return {
          'songs': List.empty(),
          'error': res.body,
        };
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSongSearchResults: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<List<Map<String, dynamic>>> fetchSearchResults(
    String searchQuery,
  ) async {
    if (_resultCache.containsKey('search_$searchQuery')) {
      return _resultCache['search_$searchQuery'] as List<Map<String, dynamic>>;
    }
    final Map<String, List> result = {};
    final Map<int, String> position = {};
    List searchedSongList = [];
    List searchedAlbumList = [];
    List searchedPlaylistList = [];
    List searchedArtistList = [];
    List searchedTopQueryList = [];
    // List searchedShowList = [];
    // List searchedEpisodeList = [];

    final String params =
        '__call=autocomplete.get&cc=in&includeMetaTags=1&query=$searchQuery';

    final res = await getResponse(params, usev4: false);
    if (res.statusCode == 200) {
      final getMain = await compute(jsonDecode, res.body) as Map;
      
      final List albumResponseList = getMain['albums']?['data'] as List? ?? [];
      final List playlistResponseList = getMain['playlists']?['data'] as List? ?? [];
      final List artistResponseList = getMain['artists']?['data'] as List? ?? [];
      final List topQuery = getMain['topquery']?['data'] as List? ?? [];

      position[getMain['albums']?['position'] as int? ?? 0] = 'Albums';
      position[getMain['playlists']?['position'] as int? ?? 0] = 'Playlists';
      position[getMain['artists']?['position'] as int? ?? 0] = 'Artists';

      final List<Future> futures = [
        FormatResponse.formatAlbumResponse(albumResponseList, 'album').then((value) {
           if (value.isNotEmpty) result['Albums'] = value;
        }),
        FormatResponse.formatAlbumResponse(playlistResponseList, 'playlist').then((value) {
           if (value.isNotEmpty) result['Playlists'] = value;
        }),
        FormatResponse.formatAlbumResponse(artistResponseList, 'artist').then((value) {
           if (value.isNotEmpty) result['Artists'] = value;
        }),
        SaavnAPI().fetchSongSearchResults(searchQuery: searchQuery, count: 10).then((value) {
           final songs = value['songs'] as List? ?? [];
           if (songs.isNotEmpty) result['Songs'] = songs;
        }),
      ];

      if (topQuery.isNotEmpty) {
        final String topType = topQuery[0]['type'].toString();
        if (topType == 'song') {
          position[getMain['topquery']?['position'] as int? ?? 0] = 'Songs';
        } else if (topType == 'playlist' || topType == 'artist' || topType == 'album') {
          position[getMain['topquery']?['position'] as int? ?? 0] = 'Top Result';
          futures.add(
            FormatResponse.formatAlbumResponse(topQuery, topType).then((value) {
              if (value.isNotEmpty) result['Top Result'] = value;
            })
          );
        }
      }

      if (getMain['songs'] != null) {
        position[getMain['songs']['position'] as int? ?? 0] = 'Songs';
      }

      await Future.wait(futures);
    }

    final sortedKeys = position.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final List<Map<String, dynamic>> finalList = [];
    final Set<String> addedTitles = {};
    for (final entry in sortedKeys) {
      if (result.containsKey(entry.value) && !addedTitles.contains(entry.value)) {
        finalList.add({'title': entry.value, 'items': result[entry.value]});
        addedTitles.add(entry.value);
      }
    }
    _resultCache['search_$searchQuery'] = finalList;
    return finalList;
  }

  Future<List<String>> getAutoSuggestions(String searchQuery) async {
    final List<String> suggestions = [];
    final String params =
        '__call=autocomplete.get&cc=in&includeMetaTags=1&query=$searchQuery';

    final res = await getResponse(params, usev4: false);
    if (res.statusCode == 200) {
      final getMain = await compute(jsonDecode, res.body) as Map;
      final sections = [
        'topquery',
        'songs',
        'albums',
        'artists',
        'playlists',
      ];

      for (final section in sections) {
        final List data = getMain[section]?['data'] as List? ?? [];
        for (final item in data) {
          if (item['title'] != null) {
            suggestions.add(item['title'].toString().unescape());
          } else if (item['name'] != null) {
            suggestions.add(item['name'].toString().unescape());
          } else if (item['song'] != null) {
            suggestions.add(item['song'].toString().unescape());
          }
        }
      }
    }
    return suggestions.toSet().toList();
  }

  Future<List<Map>> fetchAlbums({
    required String searchQuery,
    required String type,
    int count = 20,
    int page = 1,
  }) async {
    final String cacheKey = 'album_search_${type}_${searchQuery}_${count}_$page';
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey] as List<Map>;
    }
    String? params;
    if (type == 'playlist') {
      params =
          'p=$page&q=$searchQuery&n=$count&${endpoints["playlistResults"]}';
    }
    if (type == 'album') {
      params = 'p=$page&q=$searchQuery&n=$count&${endpoints["albumResults"]}';
    }
    if (type == 'artist') {
      params = 'p=$page&q=$searchQuery&n=$count&${endpoints["artistResults"]}';
    }

    final res = await getResponse(params!);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body);
      final List responseList = getMain['results'] as List;
      final result = await FormatResponse.formatAlbumResponse(responseList, type);
      _resultCache[cacheKey] = result;
      return result;
    }
    return List.empty();
  }

  Future<Map> fetchAlbumSongs(String albumId) async {
    if (_metadataCache.containsKey('album_$albumId')) {
      return _metadataCache['album_$albumId'] as Map;
    }
    final String params = '${endpoints['albumDetails']}&cc=in&albumid=$albumId';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final getMain = json.decode(res.body);
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          final result = {
            'songs':
                await FormatResponse.formatSongsInList(responseList),
            'error': '',
          };
          _metadataCache['album_$albumId'] = result;
          return result;
        }
      }
      Logger.root.severe('Songs not found in fetchAlbumSongs: ${res.body}');
      return {
        'songs': List.empty(),
        'error': '',
      };
    } catch (e) {
      Logger.root.severe('Error in fetchAlbumSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<Map<String, List>> fetchArtistSongs({
    required String artistToken,
    String category = '',
    String sortOrder = '',
  }) async {
    final Map<String, List> data = {};
    final String params =
        '${endpoints["fromToken"]}&type=artist&p=&n_song=50&n_album=50&sub_type=&category=$category&sort_order=$sortOrder&includeMetaTags=0&token=$artistToken';
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      final getMain = json.decode(res.body) as Map;
      final List topSongsResponseList = getMain['topSongs'] as List;
      Logger.root.info('fetchArtistSongs: RAW topSongs length: ${topSongsResponseList.length}');
      if (topSongsResponseList.isNotEmpty) {
        final firstSong = topSongsResponseList[0];
        Logger.root.info('fetchArtistSongs: First raw item keys: ${firstSong.keys.toList()}');
        Logger.root.info('fetchArtistSongs: First raw item values: $firstSong');
      }
      final List latestReleaseResponseList = getMain['latest_release'] as List;
      final List topAlbumsResponseList = getMain['topAlbums'] as List;
      final List singlesResponseList = getMain['singles'] as List;
      final List dedicatedResponseList =
          getMain['dedicated_artist_playlist'] as List;
      final List featuredResponseList =
          getMain['featured_artist_playlist'] as List;
      final List similarArtistsResponseList = getMain['similarArtists'] as List;

      final List topSongsSearchedList =
          await FormatResponse.formatSongsInList(
        topSongsResponseList,
      );
      Logger.root.info('fetchArtistSongs: Formatted topSongs length: ${topSongsSearchedList.length}');
      if (topSongsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topSongs']?['title']?.toString() ??
            'Top Songs'] = topSongsSearchedList;
      }

      final List latestReleaseSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        latestReleaseResponseList,
      );
      if (latestReleaseSearchedList.isNotEmpty) {
        data[getMain['modules']?['latest_release']?['title']?.toString() ??
            'Latest Releases'] = latestReleaseSearchedList;
      }

      final List topAlbumsSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        topAlbumsResponseList,
      );
      if (topAlbumsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topAlbums']?['title']?.toString() ??
            'Top Albums'] = topAlbumsSearchedList;
      }

      final List singlesSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        singlesResponseList,
      );
      if (singlesSearchedList.isNotEmpty) {
        data[getMain['modules']?['singles']?['title']?.toString() ??
            'Singles'] = singlesSearchedList;
      }

      final List dedicatedSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        dedicatedResponseList,
      );
      if (dedicatedSearchedList.isNotEmpty) {
        data[getMain['modules']?['dedicated_artist_playlist']?['title']
                ?.toString() ??
            'Dedicated Playlists'] = dedicatedSearchedList;
      }

      final List featuredSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        featuredResponseList,
      );
      if (featuredSearchedList.isNotEmpty) {
        data[getMain['modules']?['featured_artist_playlist']?['title']
                ?.toString() ??
            'Featured Playlists'] = featuredSearchedList;
      }

      final List similarArtistsSearchedList =
          await FormatResponse.formatSimilarArtistsResponse(
        similarArtistsResponseList,
      );
      if (similarArtistsSearchedList.isNotEmpty) {
        data[getMain['modules']?['similarArtists']?['title']?.toString() ??
            'Similar Artists'] = similarArtistsSearchedList;
      }
    }
    return data;
  }

  Future<Map> fetchPlaylistSongs(String playlistId, {String? language}) async {
    final String params =
        '${endpoints["playlistDetails"]}&cc=in&listid=$playlistId';
    try {
      final res = await getResponse(params, cc: language);
      if (res.statusCode == 200) {
        final getMain = json.decode(res.body);
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          return {
            'songs': await FormatResponse.formatSongsInList(
              responseList,
            ),
            'error': '',
          };
        }
        return {
          'songs': List.empty(),
          'error': '',
        };
      } else {
        return {
          'songs': List.empty(),
          'error': res.body,
        };
      }
    } catch (e) {
      Logger.root.severe('Error in fetchPlaylistSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<Map> fetchSongDetails(String songId) async {
    final Map cachedSong = Hive.box('cache').get(songId, defaultValue: {}) as Map;
    if (cachedSong.isNotEmpty) {
      return cachedSong;
    }
    final String params = 'pids=$songId&${endpoints["songDetails"]}';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final Map data = await compute(jsonDecode, res.body) as Map;
        return await FormatResponse.formatSingleSongResponse(
          data['songs'][0] as Map,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSongDetails: $e');
    }
    return {};
  }
}
