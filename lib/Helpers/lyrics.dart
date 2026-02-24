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
import 'dart:math';

// import 'package:audiotagger/audiotagger.dart';
// import 'package:audiotagger/models/tag.dart';
import 'package:orbit/APIs/spotify_api.dart';
import 'package:orbit/Helpers/matcher.dart';
import 'package:orbit/Helpers/spotify_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

// ignore: avoid_classes_with_only_static_members
class Lyrics {
  static Future<Map<String, String>> getLyrics({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? language,
    required bool saavnHas,
    Duration? duration,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': '',
      'id': id,
    };

    // Check Cache first
    try {
      final box = Hive.box('lyrics');
      final cached = box.get(id);
      if (cached != null && cached is Map) {
        Logger.root.info('Found lyrics in cache for $id');
        return Map<String, String>.from(cached);
      }
    } catch (e) {
      Logger.root.severe('Error reading lyrics cache', e);
    }

    // User-specified ranking logic:
    // Rank 1: Synced + Native (Telugu/Hindi)
    // Rank 2: Synced + Romanized
    // Rank 3: Static + Native
    // Rank 4: Static + Romanized
    int getScore(String lyrics, String type) {
      if (lyrics.isEmpty) return 99; // No result
      final bool isSynced = type == 'lrc' || lyrics.startsWith('[');
      final bool isLatin = _isLatinScript(lyrics);
      
      if (isSynced && !isLatin) return 1;
      if (isSynced && isLatin) return 2;
      if (!isSynced && !isLatin) return 3;
      return 4;
    }

    String generateMetadataLyrics(String title, String artist, Duration? dur) {
      final int totalMs = dur?.inMilliseconds ?? 300000;
      final StringBuffer sb = StringBuffer();
      sb.writeln('[00:00.00]🎵 $title');
      sb.writeln('[00:05.00]👤 $artist');
      sb.writeln('[00:10.00]✨ Enjoy the rhythm!');
      
      if (totalMs > 30000) {
        final int midMin = (totalMs ~/ 2) ~/ 60000;
        final int midSec = ((totalMs ~/ 2) % 60000) ~/ 1000;
        sb.writeln('[${midMin.toString().padLeft(2, '0')}:${midSec.toString().padLeft(2, '0')}.00]🎸 Music Playing...');
        
        final int endMin = (totalMs - 5000) ~/ 60000;
        final int endSec = ((totalMs - 5000) % 60000) ~/ 1000;
        sb.writeln('[${endMin.toString().padLeft(2, '0')}:${endSec.toString().padLeft(2, '0')}.00]🎬 ${title} - ${artist}');
      }
      return sb.toString();
    }

    String autoSync(String text, Duration? dur) {
      if (dur == null || text.isEmpty) return text;
      final List<String> lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return text;
      
      final int totalMs = dur.inMilliseconds;
      final double interval = totalMs / (lines.length + 1);
      
      final StringBuffer sb = StringBuffer();
      for (int i = 0; i < lines.length; i++) {
        final int currentMs = (i * interval).toInt();
        final int min = currentMs ~/ 60000;
        final int sec = (currentMs % 60000) ~/ 1000;
        final int ms = (currentMs % 1000) ~/ 10;
        final String timestamp = '[${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}]';
        sb.writeln('$timestamp${lines[i]}');
      }
      return sb.toString();
    }

    try {
      final List<Future<Map<String, String>>> futures = [
        getLrcLibLyrics(title, artist, album: album, duration: duration).timeout(
            const Duration(seconds: 5),
            onTimeout: () => {'lyrics': '', 'type': 'lrc', 'source': 'LRCLIB'}),
        getSpotifyLyrics(title, artist, album: album).timeout(const Duration(seconds: 5), 
            onTimeout: () => {'lyrics': '', 'type': 'lrc', 'source': 'Spotify'}),
        getNetEaseLyrics(title, artist, album: album).timeout(const Duration(seconds: 5),
            onTimeout: () => {'lyrics': '', 'type': 'lrc', 'source': 'NetEase'}),
        getMusixMatchLyrics(title: title, artist: artist, album: album).then((l) => 
            {'lyrics': l, 'type': 'text', 'source': 'Musixmatch'}).timeout(const Duration(seconds: 5),
            onTimeout: () => {'lyrics': '', 'type': 'text', 'source': 'Musixmatch'}),
      ];
      
      futures.add(getSaavnLyrics(id).then((l) => {'lyrics': l, 'type': 'text', 'source': 'Jiosaavn (Native)'}).timeout(const Duration(seconds: 5), onTimeout: () => {'lyrics': '', 'type': 'text', 'source': 'Jiosaavn (Native)'}));
      
      futures.add(getSaavnLyricsBySearch(title, artist, album: album, language: language)
          .then((l) => {'lyrics': l, 'type': 'text', 'source': 'Jiosaavn (Search)'}).timeout(const Duration(seconds: 5), onTimeout: () => {'lyrics': '', 'type': 'text', 'source': 'Jiosaavn (Search)'}));

      final List<Map<String, String>> responses = await Future.wait(futures);
      
      Map<String, String>? bestMatch;
      int bestRank = 100;

      for (final res in responses) {
        final String lyricsText = res['lyrics'] ?? '';
        if (lyricsText.isEmpty) continue;
        
        final int rank = getScore(lyricsText, res['type'] ?? 'text');
        if (rank < bestRank) {
          bestRank = rank;
          bestMatch = res;
        }
        if (rank == 1) break;
      }

      // If we found Rank 1 or 2 (Synced), return it
      if (bestMatch != null && bestRank <= 2) {
        result['lyrics'] = bestMatch['lyrics']!;
        result['type'] = 'lrc';
        result['source'] = bestMatch['source']!;
        
        // Save to cache
        Hive.box('lyrics').put(id, result);
        return result;
      }
      
      // If no synced found, or we have poor results, try Google Deep Search
      Logger.root.info('Parallel fetch found sub-optimal results (Rank $bestRank), triggering Super-Deep Google Search');
      final String googleRes = await getGoogleLyrics(title: title, artist: artist, album: album, language: language);
      if (googleRes != '') {
        final int googleRank = getScore(googleRes, 'text');
        if (googleRank < bestRank) {
           bestRank = googleRank;
           bestMatch = {'lyrics': googleRes, 'type': 'text', 'source': 'Google (Deep Search)'};
        }
      }

      // If we have any lyrics at all (even Static Rank 3 or 4), apply Auto-Sync and return
      if (bestMatch != null && bestMatch['lyrics'] != '') {
        Logger.root.info('Applying Auto-Sync to Rank $bestRank lyrics from ${bestMatch['source']}');
        result['lyrics'] = autoSync(bestMatch['lyrics']!, duration);
        result['type'] = 'lrc';
        result['source'] = '${bestMatch['source']} (Auto-Synced)';
        
        // Save to cache
        Hive.box('lyrics').put(id, result);
        return result;
      }

      // ULTIMATE FALLBACK: If NO lyrics found anywhere, "Create" them from Metadata
      Logger.root.info('NO LYRICS FOUND ANYWHERE. Generating Metadata-based moving experience.');
      result['lyrics'] = generateMetadataLyrics(title, artist, duration);
      result['type'] = 'lrc';
      result['source'] = 'App Generated';
    } catch (e) {
      Logger.root.severe('Error in Universal Parallel getLyrics', e);
      // Even on error, generate something
      result['lyrics'] = generateMetadataLyrics(title, artist, duration);
      result['type'] = 'lrc';
      result['source'] = 'App Generated (Fallback)';
    }

    return result;
  }

  static bool _isLatinScript(String text) {
    if (text.isEmpty) return false;
    // Clean text by removing things that aren't letters (punctuation, numbers, ads)
    final String onlyLetters = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').replaceAll(RegExp(r'\s+'), '');
    if (onlyLetters.isEmpty) {
      // If it's all rhythm cues like "Oh Oh Oh", it might still be Latin script
      return text.contains(RegExp(r'[a-zA-Z]'));
    }
    
    int latinCount = 0;
    for (int i = 0; i < onlyLetters.length; i++) {
        if (onlyLetters.codeUnitAt(i) < 0x0100) latinCount++;
    }
    return (latinCount / onlyLetters.length) > 0.6;
  }

  static Future<Map<String, String>> getLrcLibLyrics(
    String title,
    String artist, {
    String? album,
    Duration? duration,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'LRCLIB',
    };
    try {
      final String cleanTitle = title
          .split('(').first
          .split('-').first
          .replaceAll(RegExp(r'Official\s+Video|Official\s+Audio|Lyrical|Remix|Cover', caseSensitive: false), '')
          .trim();
      final String firstArtist = artist.split(',').first.split('&').first.trim();

      // 1. Try exact match first using /api/get if duration is available
      if (duration != null && duration.inSeconds > 0) {
        final Map<String, String> params = {
          'track_name': cleanTitle,
          'artist_name': firstArtist,
          'duration': duration.inSeconds.toString(),
        };
        if (album != null && album.isNotEmpty) {
          params['album_name'] = album.split('(').first.trim();
        }

        final Uri getUrl = Uri.https('lrclib.net', '/api/get', params);
        final Response getRes = await get(getUrl);
        if (getRes.statusCode == 200) {
          final Map data = json.decode(utf8.decode(getRes.bodyBytes)) as Map;
          final String content =
              (data['syncedLyrics'] ?? data['plainLyrics'] ?? '').toString();
          if (content.isNotEmpty) {
            result['lyrics'] = content;
            result['type'] = data['syncedLyrics'] != null ? 'lrc' : 'text';
            return result;
          }
        }
      }

      // 2. Fallback to Search
      final List<String> queries = [
        '$cleanTitle $firstArtist',
        '$cleanTitle $firstArtist lyrics',
        cleanTitle,
      ];
      
      for (final query in queries) {
        final Uri url = Uri.https('lrclib.net', '/api/search', {'q': query});
        final Response res = await get(url);
        if (res.statusCode == 200) {
          final List data = json.decode(utf8.decode(res.bodyBytes)) as List;
          if (data.isNotEmpty) {
            final List validResults = data.where((item) {
              final String content = (item['syncedLyrics'] ?? item['plainLyrics'] ?? '').toString();
              return content.isNotEmpty && _isLatinScript(content);
            }).toList();
            
            if (validResults.isNotEmpty) {
              final Map bestMatch = validResults.firstWhere(
                (item) => item['syncedLyrics'] != null && item['syncedLyrics'] != '',
                orElse: () => validResults.first,
              ) as Map;
              result['lyrics'] = (bestMatch['syncedLyrics'] ?? bestMatch['plainLyrics'] ?? '').toString();
              result['type'] = bestMatch['syncedLyrics'] != null ? 'lrc' : 'text';
              return result;
            }
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error in getLrcLibLyrics', e);
    }
    return result;
  }

  static Future<String> getSaavnLyricsBySearch(String title, String artist, {String? album, String? language}) async {
    try {
      String cleanTitle = title.split('(').first.trim();
      final String firstArtist = artist.split(',').first.trim();

      // Resilience fix for common naming patterns and cleaning movie suffixes
      cleanTitle = cleanTitle.replaceAll(RegExp(r'\bchikri\b', caseSensitive: false), 'Chikiri');
      cleanTitle = cleanTitle.replaceAll(RegExp(r'\s*[\(\[].*?(?:From|Movie|Official|Video|Audio).*?[\)\]]', caseSensitive: false), '').trim();
      cleanTitle = cleanTitle.split('-').first.trim();

      Future<String> trySaavnSearch(String query) async {
        final List<String> endpoints = [
          '/api.php?__call=search.getResults&q=${Uri.encodeComponent(query)}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10',
          '/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(query)}&_format=json&_marker=0&api_version=4&ctx=web6dot0',
        ];

        for (final endpoint in endpoints) {
          final Uri url = Uri.https('www.jiosaavn.com', endpoint);
          final Response res = await get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'cookie': 'geo=IN',
            },
          ).timeout(const Duration(seconds: 5), onTimeout: () => Response('', 408));

          if (res.statusCode == 200) {
            final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));
            List songs = [];
            if (endpoint.contains('search.getResults')) {
              songs = decoded['results'] as List? ?? [];
            } else if (endpoint.contains('autocomplete.get')) {
              songs = decoded['songs']?['data'] as List? ?? [];
            }

            // Priority 1: Exact matches with lyrics in requested language
            if (language != null && language.isNotEmpty) {
              for (final song in songs) {
                if ((song['has_lyrics'].toString() == 'true' ||
                        song['has_lyrics'].toString() == '1') &&
                    song['language'].toString().toLowerCase() ==
                        language.toLowerCase()) {
                  final String songId = song['id'].toString();
                  Logger.root.info(
                      'Found Saavn song ID with lyrics in $language: $songId');
                  final String lyrics = await getSaavnLyrics(songId);
                  if (lyrics != '') return lyrics;
                }
              }
            }

            // Priority 2: Any song with lyrics
            for (final song in songs) {
              if (song['has_lyrics'].toString() == 'true' ||
                  song['has_lyrics'].toString() == '1') {
                final String songId = song['id'].toString();
                Logger.root.info('Found Saavn song ID with lyrics for "$query": $songId');
                final String lyrics = await getSaavnLyrics(songId);
                if (lyrics != '') return lyrics;
              }
            }
          }
        }
        return '';
      }

      String result = '';
      // 0. Try Clean Title + Album (if available)
      if (album != null && album.isNotEmpty) {
        final String cleanAlbum = album.split('(').first.trim();
        result = await trySaavnSearch('$cleanTitle $cleanAlbum');
        if (result != '') return result;
      }

      // 1. Try Clean Title + First Artist
      result = await trySaavnSearch('$cleanTitle $firstArtist');
      if (result != '') return result;

      // 2. Try Full Title + First Artist
      result = await trySaavnSearch('$title $firstArtist');
      if (result != '') return result;

      // 3. Try Clean Title only
      result = await trySaavnSearch(cleanTitle);
      if (result != '') return result;

      return '';
    } catch (e) {
      Logger.root.severe('Error in getSaavnLyricsBySearch', e);
      return '';
    }
  }

  static Future<String> getSaavnLyrics(String id) async {
    try {
      final Uri lyricsUrl = Uri.https(
        'www.jiosaavn.com',
        '/api.php?__call=lyrics.getLyrics&lyrics_id=$id&ctx=web6dot0&api_version=4&_format=json',
      );
      final Response res = await get(
        lyricsUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'cookie': 'geo=IN',
        },
      );

      if (res.statusCode != 200) {
        Logger.root.severe('Saavn Lyrics API returned status: ${res.statusCode}');
        return '';
      }

      String body = utf8.decode(res.bodyBytes);
      int startIndex = body.indexOf('{');
      int endIndex = body.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        body = body.substring(startIndex, endIndex + 1);
      }
      
      try {
        final Map fetchedLyrics = json.decode(body) as Map;
        if (fetchedLyrics['status'] == 'success' && fetchedLyrics['lyrics'] != null) {
          final String lyrics =
              _stripHtml(fetchedLyrics['lyrics'].toString().replaceAll('<br>', '\n'));
          return lyrics;
        } else {
          Logger.root.info('Saavn Lyrics API returned non-success: ${fetchedLyrics['status'] ?? body}');
        }
      } catch (e) {
        Logger.root.severe('Failed to decode Saavn lyrics JSON: $body', e);
      }
      return '';
    } catch (e) {
      Logger.root.severe('Error in getSaavnLyrics', e);
      return '';
    }
  }

  static Future<Map<String, String>> getSpotifyLyrics(
    String title,
    String artist, {
    String? album,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    await callSpotifyFunction(
      function: (String accessToken) async {
        final String cleanTitle = title.split('(').first.trim();
        final String firstArtist = artist.split(',').first.trim();
        
        var query = '$cleanTitle $firstArtist';
        if (album != null && album.isNotEmpty) {
          query = '$cleanTitle ${album.split('(').first.trim()}';
        }
        
        var value = await SpotifyApi().searchTrack(
          accessToken: accessToken,
          query: query,
          limit: 1,
        );
        if (value['tracks']['items'].length == 0) {
          value = await SpotifyApi().searchTrack(
            accessToken: accessToken,
            query: '$cleanTitle $firstArtist',
            limit: 1,
          );
        }
        if (value['tracks']['items'].length == 0) {
          value = await SpotifyApi().searchTrack(
            accessToken: accessToken,
            query: cleanTitle,
            limit: 1,
          );
        }
        try {
          // Logger.root.info(jsonEncode(value['tracks']['items'][0]));
          if (value['tracks']['items'].length == 0) {
            Logger.root.info('No song found');
            return result;
          }
          String title2 = '';
          String artist2 = '';
          try {
            title2 = value['tracks']['items'][0]['name'].toString();
            artist2 =
                value['tracks']['items'][0]['artists'][0]['name'].toString();
          } catch (e) {
            Logger.root.severe(
              'Error in extracting artist/title in getSpotifyLyrics for $title - $artist',
              e,
            );
          }
          final trackId = value['tracks']['items'][0]['id'].toString();
          if (matchSongs(
            title: title,
            artist: artist,
            title2: title2,
            artist2: artist2,
          ).matched) {
            final Map<String, String> res =
                await getSpotifyLyricsFromId(trackId);
            result['lyrics'] = res['lyrics']!;
            result['type'] = res['type']!;
            result['source'] = res['source']!;
          } else {
            Logger.root.info('Song not matched');
          }
        } catch (e) {
          Logger.root.severe('Error in getSpotifyLyrics', e);
        }
      },
      forceSign: false,
    );
    return result;
  }

  static Future<Map<String, String>> getSpotifyLyricsFromId(
    String trackId,
  ) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    try {
      final Uri lyricsUrl =
          Uri.https('spotify-lyric-api-984e7b4face0.herokuapp.com', '/', {
        'trackid': trackId,
        'format': 'lrc',
      });
      final Response res =
          await get(lyricsUrl, headers: {'Accept': 'application/json'});

      if (res.statusCode == 200) {
        final Map lyricsData = await json.decode(res.body) as Map;
        if (lyricsData['error'] == false) {
          final List lines = await lyricsData['lines'] as List;
          if (lyricsData['syncType'] == 'LINE_SYNCED') {
            result['lyrics'] = lines
                .map((e) => '[${e["timeTag"]}]${e["words"]}')
                .toList()
                .join('\n');
            result['type'] = 'lrc';
          } else {
            result['lyrics'] = lines.map((e) => e['words']).toList().join('\n');
            result['type'] = 'text';
          }
        }
      } else {
        Logger.root.severe(
          'getSpotifyLyricsFromId returned ${res.statusCode}',
          res.body,
        );
      }
      return result;
    } catch (e) {
      Logger.root.severe('Error in getSpotifyLyrics', e);
      return result;
    }
  }

  static Future<String> getGoogleLyrics({
    required String title,
    required String artist,
    String? album,
    String? language,
  }) async {
    const String url =
        'https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=';

    final List<List<String>> delimiterSets = [
      [
        '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">',
        '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">'
      ],
      [
        '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">',
        '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe tAd8D AP7Wnd">'
      ],
      [
        '<div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">',
        '</div></div></div>'
      ],
      [
        '<div class="BNeawe tAd8D AP7Wnd">',
        '</div>'
      ],
      [
        '</span></div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd">',
        '</div>'
      ],
    ];

    String lyrics = '';
    final String cleanTitle = title.split('(').first.trim();
    final String firstArtist = artist.split(',').first.trim();
    final String cleanAlbum = album?.split('(').first.trim() ?? '';

    Future<String> tryScraping(String query) async {
      try {
        final response = await get(
          Uri.parse(Uri.encodeFull('$url$query')),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        );
        final String body = response.body;
        for (final set in delimiterSets) {
          if (body.contains(set[0])) {
            String candidate = body.split(set[0]).last.split(set[1]).first;
            if (candidate.length > 50 &&
                !candidate.contains('<meta') &&
                !candidate.contains('<!DOCTYPE')) {
              return candidate.trim();
            }
          }
        }
      } catch (_) {}
      return '';
    }

    final String langSuffix = (language?.toLowerCase() == 'telugu' || language?.toLowerCase() == 'te') 
        ? ' Telugu' 
        : (language?.toLowerCase() == 'hindi' || language?.toLowerCase() == 'hi') 
            ? ' Hindi' 
            : '';

    // Try multiple queries
    if (langSuffix.isNotEmpty) {
      lyrics = await tryScraping('$cleanTitle$langSuffix lyrics');
    }
    if (lyrics == '' && cleanAlbum.isNotEmpty) {
      lyrics = await tryScraping('$cleanTitle $cleanAlbum lyrics');
    }
    if (lyrics == '') {
      lyrics = await tryScraping('$cleanTitle $firstArtist lyrics');
    }
    if (lyrics == '') {
      lyrics = await tryScraping('$cleanTitle lyrics');
    }
    if (lyrics == '') {
      lyrics = await tryScraping('$title by $artist lyrics');
    }
    if (lyrics == '' && langSuffix.isNotEmpty) {
       lyrics = await tryScraping('$cleanTitle $firstArtist$langSuffix lyrics');
    }
    if (lyrics == '') {
       lyrics = await tryScraping('$cleanTitle $firstArtist song lyrics');
    }

    // Final validation
    if (lyrics.contains('<!DOCTYPE') ||
        lyrics.contains('<html') ||
        lyrics.contains('<body') ||
        lyrics.length < 20 ||
        lyrics.contains('Requested URL not found')) {
      return '';
    }

    return _stripHtml(lyrics).trim();
  }

  static Future<Map<String, String>> getNetEaseLyrics(
    String title,
    String artist, {
    String? album,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'NetEase',
    };
    try {
      final String cleanTitle = title.split('(').first.trim();
      final String firstArtist = artist.split(',').first.trim();
      final String query = Uri.encodeComponent('$cleanTitle $firstArtist');
      final Uri searchUrl = Uri.parse(
          'https://music.163.com/api/search/get/web?s=$query&type=1&offset=0&total=true&limit=1');
      
      final Response searchRes = await get(searchUrl);
      if (searchRes.statusCode == 200) {
        final Map searchData = json.decode(searchRes.body) as Map;
        final List songs = searchData['result']?['songs'] as List? ?? [];
        if (songs.isNotEmpty) {
          final String songId = songs[0]['id'].toString();
          final Uri lyricsUrl = Uri.parse(
              'https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1');
          final Response lyricsRes = await get(lyricsUrl);
          if (lyricsRes.statusCode == 200) {
            final Map lyricsData = json.decode(lyricsRes.body) as Map;
            final String lrc = (lyricsData['lrc']?['lyric'] ?? '').toString();
            final String tlrc = (lyricsData['tlyric']?['lyric'] ?? '').toString();
            
            if (lrc.isNotEmpty) {
              result['lyrics'] = tlrc.isNotEmpty ? '$lrc\n$tlrc' : lrc;
              result['type'] = 'lrc';
              return result;
            }
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error in getNetEaseLyrics', e);
    }
    return result;
  }

  static Future<String> getOffLyrics(String path) async {
    try {
      // final Audiotagger tagger = Audiotagger();
      // final Tag? tags = await tagger.readTags(path: path);
      // return tags?.lyrics ?? '';
      return '';
    } catch (e) {
      return '';
    }
  }

  static Future<String> getLyricsLink(String song, String artist, {String? album}) async {
    const String authority = 'www.musixmatch.com';
    final String cleanTitle = song.split('(').first.trim();
    final String firstArtist = artist.split(',').first.trim();
    var unencodedPath = '/search/$cleanTitle $firstArtist';
    if (album != null && album.isNotEmpty) {
      unencodedPath = '/search/$cleanTitle ${album.split('(').first.trim()}';
    }
    final Response res = await get(Uri.https(authority, unencodedPath));
    if (res.statusCode != 200) {
      if (album != null) {
        return getLyricsLink(song, artist, album: null);
      }
      return '';
    }
    final RegExpMatch? result =
        RegExp(r'href=\"(\/lyrics\/.*?)\"').firstMatch(res.body);
    return result == null ? '' : result[1]!;
  }

  static Future<String> scrapLink(String unencodedPath) async {
    Logger.root.info('Trying to scrap lyrics from $unencodedPath');
    const String authority = 'www.musixmatch.com';
    final Response res = await get(Uri.https(authority, unencodedPath));
    if (res.statusCode != 200) return '';
    final List<String?> lyrics = RegExp(
      r'<span class=\"lyrics__content__ok\">(.*?)<\/span>',
      dotAll: true,
    ).allMatches(res.body).map((m) => m[1]).toList();

    return lyrics.isEmpty ? '' : _stripHtml(lyrics.join('\n'));
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  static Future<String> getMusixMatchLyrics({
    required String title,
    required String artist,
    String? album,
  }) async {
    try {
      final String link = await getLyricsLink(title, artist, album: album);
      Logger.root.info('Found Musixmatch Lyrics Link: $link');
      final String lyrics = await scrapLink(link);
      return lyrics;
    } catch (e) {
      Logger.root.severe('Error in getMusixMatchLyrics', e);
      return '';
    }
  }

  static String autoSync(String lyrics, Duration duration) {
    if (lyrics.isEmpty) return '';
    final List<String> lines =
        lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';

    final int totalLength = lines.length;
    final int durationMs = duration.inMilliseconds;
    // Start after 5 seconds or 5% of duration, whichever is less
    final int startOffset = min(5000, durationMs ~/ 20);
    // End before 5 seconds of end
    final int effectiveDuration = max(0, durationMs - startOffset - 5000);
    final int interval =
        totalLength > 1 ? effectiveDuration ~/ (totalLength - 1) : 0;

    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
       // Nonlinear distribution: lyrics usually start slow and cluster in the middle
       double progress = i / (totalLength - 1);
       // Power function to slightly delay early lyrics if they are many
       double curvedProgress = pow(progress, 0.9).toDouble();
       
       final int lineMs = startOffset + (curvedProgress * effectiveDuration).toInt();
       final int min = (lineMs ~/ 60000);
       final int sec = (lineMs % 60000) ~/ 1000;
       final int ms = (lineMs % 1000) ~/ 10;
       
       final String timestamp = '[${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}]';
       sb.writeln('$timestamp${lines[i]}');
    }
    return sb.toString();
  }
}
