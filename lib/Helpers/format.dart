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
import 'dart:typed_data';

import 'package:orbit/APIs/api.dart';
import 'package:orbit/Helpers/extensions.dart';
import 'package:orbit/Helpers/image_resolution_modifier.dart';
import 'package:dart_des/dart_des.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import 'package:flutter/foundation.dart';

// ignore: avoid_classes_with_only_static_members
class FormatResponse {
  static String decode(String input) {
    if (input.trim() == '') return '';
    const String key = '38346591';
    final DES desECB = DES(key: key.codeUnits);

    try {
      final Uint8List encrypted = base64.decode(input);
      final List<int> decrypted = desECB.decrypt(encrypted);
      final String decoded = utf8
          .decode(decrypted)
          .replaceAll(RegExp(r'\.mp4.*'), '.mp4')
          .replaceAll(RegExp(r'\.m4a.*'), '.m4a')
          .replaceAll(RegExp(r'\.mp3.*'), '.mp3');
      String url = decoded.replaceAll('http:', 'https:');
      if (kIsWeb) {
        url = 'http://localhost:3000/api/media?url=${Uri.encodeComponent(url)}';
      }
      return url;
    } catch (e) {
      Logger.root.severe('Error in decode: $e');
      return '';
    }
  }

  static Future<List> formatSongsResponse(
    List responseList,
    String type,
  ) async {
    final List searchedList = [];
    final List<Future<Map?>> futures = [];
    for (int i = 0; i < responseList.length; i++) {
      switch (type) {
        case 'song':
        case 'album':
        case 'playlist':
        case 'show':
        case 'mix':
          futures.add(formatSingleSongResponse(responseList[i] as Map));
          break;
        default:
          break;
      }
    }

    final List<Map?> results = await Future.wait(futures);
    for (final Map? response in results) {
      if (response != null && response.containsKey('Error')) {
        Logger.root.severe(
          'Error inside FormatSongsResponse: ${response["Error"]}',
        );
      } else if (response != null) {
        searchedList.add(response);
      }
    }
    return searchedList;
  }

  static Future<Map> formatSingleSongResponse(Map response) async {
    // Map cachedSong = Hive.box('cache').get(response['id']);
    // if (cachedSong != null) {
    //   return cachedSong;
    // }
    try {
      final List artistNames = [];
      final Map? moreInfo = response['more_info'] as Map?;
      final Map? artistMap = moreInfo?['artistMap'] as Map?;

      if (artistMap == null ||
          artistMap['primary_artists'] == null ||
          (artistMap['primary_artists'] as List).isEmpty) {
        if (artistMap == null ||
            artistMap['featured_artists'] == null ||
            (artistMap['featured_artists'] as List).isEmpty) {
          if (artistMap == null ||
              artistMap['artists'] == null ||
              (artistMap['artists'] as List).isEmpty) {
            if (moreInfo?['music'] != null) {
              artistNames.add(moreInfo!['music']);
            } else if (response['primary_artists'] != null) {
              artistNames.add(response['primary_artists']);
            } else {
              artistNames.add('Unknown');
            }
          } else {
            try {
              artistMap!['artists'][0]['id'].forEach((element) {
                artistNames.add(element['name']);
              });
            } catch (e) {
              (artistMap!['artists'] as List).forEach((element) {
                artistNames.add(element['name']);
              });
            }
          }
        } else {
          (artistMap!['featured_artists'] as List).forEach((element) {
            artistNames.add(element['name']);
          });
        }
      } else {
        (artistMap['primary_artists'] as List).forEach((element) {
          artistNames.add(element['name']);
        });
      }

      final String? encryptedMediaUrl = moreInfo?['encrypted_media_url']?.toString() ??
          response['encrypted_media_url']?.toString();

      return {
        'id': response['id'],
        'type': response['type'],
        'album': (moreInfo?['album'] ?? response['album']).toString().unescape(),
        'year': response['year'],
        'duration': moreInfo?['duration'] ?? response['duration'],
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        '320kbps': moreInfo?['320kbps'] ?? response['320kbps'],
        'has_lyrics': moreInfo?['has_lyrics'] ?? response['has_lyrics'],
        'lyrics_snippet':
            (moreInfo?['lyrics_snippet'] ?? response['lyrics_snippet'] ?? '').toString().unescape(),
        'release_date': moreInfo?['release_date'] ?? response['release_date'],
        'album_id': moreInfo?['album_id'] ?? response['album_id'],
        'subtitle': response['subtitle'].toString().unescape(),
        'title': (response['title'] ?? response['song']).toString().unescape(),
        'artist': artistNames.join(', ').unescape(),
        'album_artist': moreInfo?['music'] ?? response['music'],
        'image': getImageUrl(response['image']?.toString()),
        'perma_url': response['perma_url'],
        'url': encryptedMediaUrl != null ? decode(encryptedMediaUrl) : '',
      };
      // Hive.box('cache').put(response['id'].toString(), info);
    } catch (e) {
      Logger.root.severe('Error inside FormatSingleSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleAlbumSongResponse(Map response) async {
    try {
      final List artistNames = [];
      if (response['primary_artists'] == null ||
          response['primary_artists'].toString().trim() == '') {
        if (response['featured_artists'] == null ||
            response['featured_artists'].toString().trim() == '') {
          if (response['singers'] == null ||
              response['singer'].toString().trim() == '') {
            response['singers'].toString().split(', ').forEach((element) {
              artistNames.add(element);
            });
          } else {
            artistNames.add('Unknown');
          }
        } else {
          response['featured_artists']
              .toString()
              .split(', ')
              .forEach((element) {
            artistNames.add(element);
          });
        }
      } else {
        response['primary_artists'].toString().split(', ').forEach((element) {
          artistNames.add(element);
        });
      }

      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['album'].toString().unescape(),
        // .split('(')
        // .first
        'year': response['year'],
        'duration': response['duration'],
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        '320kbps': response['320kbps'],
        'has_lyrics': response['has_lyrics'],
        'lyrics_snippet': response['lyrics_snippet'].toString().unescape(),
        'release_date': response['release_date'],
        'album_id': response['album_id'],
        'subtitle':
            '${response["primary_artists"].toString().trim()} - ${response["album"].toString().trim()}'
                .unescape(),

        'title': response['song'].toString().unescape(),
        // .split('(')
        // .first
        'artist': artistNames.join(', ').unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'perma_url': response['perma_url'],
        'url': decode(response['encrypted_media_url'].toString()),
      };
    } catch (e) {
      Logger.root.severe('Error inside FormatSingleAlbumSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List<Map>> formatAlbumResponse(
    List responseList,
    String type,
  ) async {
    final List<Map> searchedAlbumList = [];
    final List<Future<Map?>> futures = [];
    for (int i = 0; i < responseList.length; i++) {
      switch (type) {
        case 'album':
          futures.add(formatSingleAlbumResponse(responseList[i] as Map));
          break;
        case 'artist':
          futures.add(formatSingleArtistResponse(responseList[i] as Map));
          break;
        case 'playlist':
          futures.add(formatSinglePlaylistResponse(responseList[i] as Map));
          break;
        case 'show':
          futures.add(formatSingleShowResponse(responseList[i] as Map));
          break;
        default:
          futures.add(Future.value(null));
      }
    }

    final List<Map?> results = await Future.wait(futures);

    for (int i = 0; i < results.length; i++) {
      final Map? response = results[i];
      if (response == null) {
        Logger.root.severe('Response is null for $type at index $i');
        continue;
      }
      if (response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatAlbumResponse: ${response["Error"]}',
        );
      } else {
        searchedAlbumList.add(response);
      }
    }
    return searchedAlbumList;
  }

  static Future<Map> formatSingleAlbumResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'year': response['more_info']?['year'] ?? response['year'],
        'language': response['more_info']?['language'] == null
            ? response['language'].toString().capitalize()
            : response['more_info']['language'].toString().capitalize(),
        'genre': response['more_info']?['language'] == null
            ? response['language'].toString().capitalize()
            : response['more_info']['language'].toString().capitalize(),
        'album_id': response['id'],
        'subtitle': (response['description'] == null
                ? response['subtitle'].toString().unescape()
                : response['description'].toString().unescape())
            .replaceAll(
          '0 Songs',
          '${response['more_info']?['song_count'] ?? (response['more_info']?['song_pids'] == null ? 0 : response['more_info']['song_pids'].toString().split(', ').length)} Songs',
        ),
        'title': response['title'].toString().unescape(),
        'artist': response['music'] == null
            ? (response['more_info']?['music'] == null)
                ? (response['more_info']?['artistMap']?['primary_artists'] ==
                            null ||
                        (response['more_info']?['artistMap']?['primary_artists']
                                as List)
                            .isEmpty)
                    ? ''
                    : response['more_info']['artistMap']['primary_artists'][0]
                            ['name']
                        .toString()
                        .unescape()
                : response['more_info']['music'].toString().unescape()
            : response['music'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'count': response['more_info']?['song_count'] ??
            (response['more_info']?['song_pids'] == null
                ? 0
                : response['more_info']['song_pids']
                    .toString()
                    .split(', ')
                    .length),
        'songs_pids': response['more_info']['song_pids'].toString().split(', '),
        'perma_url': response['url'].toString(),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleAlbumResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSinglePlaylistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'language': response['language'] == null
            ? response['more_info']['language'].toString().capitalize()
            : response['language'].toString().capitalize(),
        'genre': response['language'] == null
            ? response['more_info']['language'].toString().capitalize()
            : response['language'].toString().capitalize(),
        'playlistId': response['id'],
        'subtitle': (response['description'] == null
                ? response['subtitle'].toString().unescape()
                : response['description'].toString().unescape())
            .replaceAll('0 Songs',
                '${response['list_count'] ?? response['more_info']?['song_count'] ?? 0} Songs'),
        'title': response['title'].toString().unescape(),
        'artist': response['extra'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'perma_url': response['url'].toString(),
        'count': response['list_count'] ??
            response['more_info']?['song_count'] ??
            0,
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSinglePlaylistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleArtistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'] == null
            ? response['name'].toString().unescape()
            : response['title'].toString().unescape(),
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        'artistId': response['id'],
        'artistToken': response['url'] == null
            ? response['perma_url'].toString().split('/').last
            : response['url'].toString().split('/').last,
        'subtitle': response['description'] == null
            ? response['role'].toString().capitalize()
            : response['description'].toString().unescape(),
        'title': response['title'] == null
            ? response['name'].toString().unescape()
            : response['title'].toString().unescape(),
        // .split('(')
        // .first
        'perma_url': response['url'].toString(),
        'artist': response['title'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleArtistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List> formatArtistTopAlbumsResponse(List responseList) async {
    final List result = [];
    for (int i = 0; i < responseList.length; i++) {
      final Map response =
          await formatSingleArtistTopAlbumSongResponse(responseList[i] as Map);
      if (response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatArtistTopAlbumsResponse: ${response["Error"]}',
        );
      } else {
        result.add(response);
      }
    }
    return result;
  }

  static Future<Map> formatSingleArtistTopAlbumSongResponse(
    Map response,
  ) async {
    try {
      final List artistNames = [];
      if (response['more_info']?['artistMap']?['primary_artists'] == null ||
          response['more_info']['artistMap']['primary_artists'].length == 0) {
        if (response['more_info']?['artistMap']?['featured_artists'] == null ||
            response['more_info']['artistMap']['featured_artists'].length ==
                0) {
          if (response['more_info']?['artistMap']?['artists'] == null ||
              response['more_info']['artistMap']['artists'].length == 0) {
            artistNames.add('Unknown');
          } else {
            response['more_info']['artistMap']['artists'].forEach((element) {
              artistNames.add(element['name']);
            });
          }
        } else {
          response['more_info']['artistMap']['featured_artists']
              .forEach((element) {
            artistNames.add(element['name']);
          });
        }
      } else {
        response['more_info']['artistMap']['primary_artists']
            .forEach((element) {
          artistNames.add(element['name']);
        });
      }

      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        // .split('(')
        // .first
        'year': response['year'],
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        'album_id': response['id'],
        'subtitle': response['subtitle'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        // .split('(')
        // .first
        'artist': artistNames.join(', ').unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root
          .severe('Error inside formatSingleArtistTopAlbumSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List> formatSimilarArtistsResponse(List responseList) async {
    final List result = [];
    for (int i = 0; i < responseList.length; i++) {
      final Map response =
          await formatSingleSimilarArtistResponse(responseList[i] as Map);
      if (response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatSimilarArtistsResponse: ${response["Error"]}',
        );
      } else {
        result.add(response);
      }
    }
    return result;
  }

  static Future<Map> formatSingleSimilarArtistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'artist': response['name'].toString().unescape(),
        'title': response['name'].toString().unescape(),
        'subtitle': response['dominantType'].toString().capitalize(),
        'image': getImageUrl(response['image_url'].toString()),
        'artistToken': response['perma_url'].toString().split('/').last,
        'perma_url': response['perma_url'].toString(),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleSimilarArtistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleShowResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'subtitle': response['description'] == null
            ? response['subtitle'].toString().unescape()
            : response['description'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleShowResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatHomePageData(Map data) async {
    try {
      Logger.root.info('formatHomePageData processing ${data.keys.length} root keys');
      final List<String> modulesWithData = [];
      
      // Known keys that might be in the root of the response
      final List<String> baseKeys = [
        'new_trending',
        'new_albums',
        'new_releases',
        'city_mod',
        'charts',
        'tag_mixes',
        'top_playlists',
        'radio',
        'artist_recos',
      ];

      for (final key in baseKeys) {
        if (data[key] != null && data[key] is List && (data[key] as List).isNotEmpty) {
          data[key] = await formatSongsInList(data[key] as List);
          modulesWithData.add(key);
          
          if (key == 'city_mod') {
            Logger.root.info('formatHomePageData: First 3 city_mod items:');
            for (var i = 0; i < (data[key] as List).length && i < 3; i++) {
              final item = data[key][i];
              Logger.root.info('city_mod item $i: title="${item["title"]}", type="${item["type"]}", subtitle="${item["subtitle"]}", count="${item["count"]}"');
            }
          }
          
          // Ensure module metadata exists for this key
          if (data['modules'] is! Map) {
            data['modules'] = {};
          }
          if (data['modules'][key] == null) {
            String title = key.toString().capitalize().replaceAll('_', ' ');
            if (key == 'city_mod') {
              title = 'What\'s Hot'; // Default title for city module
            } else if (key == 'artist_recos') {
              title = 'Recommended Artists';
            } else if (key == 'top_playlists') {
              title = 'Top Playlists';
            }
            data['modules'][key] = {
              'title': title,
              'subtitle': '',
            };
            Logger.root.info('Added default metadata for module: $key');
          }
        }
      }

      final List<String> promoKeys = [];
      final List<String> promoKeysTemp = [];
      
      if (data['modules'] != null && data['modules'] is Map) {
        data['modules'].forEach((k, v) {
          final String key = k.toString();
          
          // Check if data is nested within the module object or exists in root as a Map
          if (v is Map) {
            Logger.root.info('Module $key (Map) keys: ${v.keys.toList()}');
            if (data[key] == null || data[key] is! List) {
              if (v['data'] != null && v['data'] is List) {
                data[key] = v['data'];
              } else if (v['list'] != null && v['list'] is List) {
                data[key] = v['list'];
              } else if (v['source'] != null && v['source'] is List) {
                data[key] = v['source'];
              }
            }
          }

          if (key.startsWith('promo')) {
            if (data[key] != null && data[key] is List && (data[key] as List).isNotEmpty) {
              Logger.root.info('Promo Module $key has ${(data[key] as List).length} items. First item type: ${(data[key] as List)[0]['type']}');
              if (data[key][0]['type'] == 'song' &&
                  (data[key][0]['mini_obj'] as bool? ?? false)) {
                promoKeysTemp.add(key);
              } else {
                promoKeys.add(key);
              }
            }
          } else if (!modulesWithData.contains(key)) {
            if (data[key] != null && data[key] is List && (data[key] as List).isNotEmpty) {
              modulesWithData.add(key);
            }
          }
        });
      }

      // Format promo lists and any newly discovered modules in parallel
      final List<String> keysToFormat = [...promoKeys, ...modulesWithData.where((k) => !baseKeys.contains(k))];
      Logger.root.info('formatHomePageData keysToFormat: $keysToFormat');
      await Future.wait(keysToFormat.map((key) async {
        try {
          data[key] = await formatSongsInList(data[key] as List);
        } catch (e) {
          Logger.root.severe('Error formatting module $key in formatHomePageData: $e');
        }
      }));

      data['collections'] = [
        ...modulesWithData,
        ...promoKeys,
      ];
      data['collections_temp'] = promoKeysTemp;
    } catch (e) {
      Logger.root.severe('Error inside formatHomePageData: $e');
    }
    return data;
  }

  static Future<Map> formatPromoLists(Map data) async {
    try {
      final List promoList = data['collections_temp'] as List;
      Logger.root.info('formatPromoLists processing ${promoList.length} promo modules: $promoList');
      await Future.wait(promoList.map((key) async {
        try {
           Logger.root.info('formatPromoLists formatting $key');
           data[key] = await formatSongsInList(data[key] as List);
        } catch (e) {
           Logger.root.severe('Error formatting module $key in formatPromoLists: $e');
        }
      }));
      data['collections'].addAll(promoList);
      data['collections_temp'] = [];
    } catch (e) {
      Logger.root.severe('Error inside formatPromoLists: $e');
    }
    return data;
  }

  static Future<List> formatSongsInList(List list) async {
    if (list.isNotEmpty) {
      final List<Future> futures = [];
      for (int i = 0; i < list.length; i++) {
        final Map item = list[i] as Map;
        // Some APIs (like artist top songs) might return songs without 'type: song'
        // or with 'type' as empty string.
        final String type = item['type']?.toString() ?? '';
        Logger.root.info('formatSongsInList: Item $i type: "$type", id: ${item['id']}, title: ${item['title']}');
        
        if (type == 'song' || (type.isEmpty && item.containsKey('id') && item.containsKey('title'))) {
          Logger.root.info('formatSongsInList: PASSED CHECK for item $i');
          futures.add(() async {
            if ((item['mini_obj'] as bool? ?? false) || !item.containsKey('more_info')) {
              // If it's a mini object or missing details, fetch full song details
              Logger.root.info('formatSongsInList: Fetching details for mini/incomplete song ${item['id']}');
              Map cachedDetails = Hive.box('cache')
                  .get(item['id'].toString(), defaultValue: {}) as Map;
              if (cachedDetails.isEmpty) {
                cachedDetails =
                    await SaavnAPI().fetchSongDetails(item['id'].toString());
                Hive.box('cache')
                    .put(cachedDetails['id'].toString(), cachedDetails);
              }
              list[i] = cachedDetails;
            } else {
              list[i] = await formatSingleSongResponse(item);
            }
          }());
        } else if (type == 'album') {
          futures.add(() async {
            list[i] = await formatSingleAlbumResponse(item);
          }());
        } else if (type == 'playlist') {
          futures.add(() async {
            list[i] = await formatSinglePlaylistResponse(item);
          }());
        } else if (type == 'show') {
          futures.add(() async {
            list[i] = await formatSingleShowResponse(item);
          }());
        }
      }
      await Future.wait(futures);
    }
    list.removeWhere((value) => value == null);
    return list;
  }
}
