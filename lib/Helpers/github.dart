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

import 'package:http/http.dart';
import 'package:logging/logging.dart';

class GitHub {
  static String repo = 'rameshreddymrec/Orbit';
  static String baseUrl = 'api.github.com';
  static Map<String, String> headers = {};
  static Map<String, String> endpoints = {
    'repo': '/repos',
    'releases': '/releases',
  };
  Map releasesData = {};

  static final GitHub _singleton = GitHub._internal();
  factory GitHub() {
    return _singleton;
  }
  GitHub._internal();

  static Future<Response> getResponse() async {
    final Uri url = Uri.https(
      baseUrl,
      '${endpoints["repo"]}/$repo${endpoints["releases"]}',
    );

    return get(url, headers: headers).onError((error, stackTrace) {
      return Response(
        {
          'status': false,
          'message': error.toString(),
        }.toString(),
        404,
      );
    });
  }

  static Future<Map> fetchReleases() async {
    final res = await getResponse();
    if (res.statusCode == 200) {
      final resp = json.decode(res.body);
      if (resp is List) {
        return resp[0] as Map;
      } else if (resp is Map) {
        Logger.root.severe('Failed to fetch releases', resp['message']);
      }
    } else {
      Logger.root.severe('Failed to fetch releases', res.body);
    }
    return {};
  }

  static Future<Map> getLatestRelease() async {
    Logger.root.info('Getting Latest Release info');
    final Map latestRelease = await fetchReleases();
    final String version = ((latestRelease['tag_name'] as String?) ?? 'v0.0.0')
        .replaceAll('v', '');
    
    String? downloadUrl;
    if (latestRelease['assets'] is List) {
      for (final asset in latestRelease['assets'] as List) {
        if (asset['name'] != null && (asset['name'] as String).endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    final String? changelog = latestRelease['body'] as String?;
    final bool isForce = changelog?.contains('FORCE_UPDATE') ?? false;

    return {
      'version': version,
      'downloadUrl': downloadUrl,
      'changelog': changelog?.replaceAll('FORCE_UPDATE', '')?.trim(),
      'isForce': isForce,
    };
  }

  static Future<String> getLatestVersion() async {
    final Map release = await getLatestRelease();
    return release['version'] as String;
  }
}
