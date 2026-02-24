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

import 'package:logging/logging.dart';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class Updater {
  static Future<void> downloadAndInstall(
    String url,
    String version, {
    Function(double)? onProgress,
  }) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/Orbit_$version.apk';

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final result = await OpenFilex.open(savePath);
      Logger.root.info('Open file result: ${result.message}');
    } catch (e) {
      Logger.root.severe('Error downloading or installing update: $e');
      rethrow;
    }
  }
}

bool compareVersion(String latestVersion, String currentVersion) {
  bool update = false;
  final List latestList = latestVersion.split('.');
  final List currentList = currentVersion.split('.');

  for (int i = 0; i < latestList.length; i++) {
    try {
      if (int.parse(latestList[i] as String) >
          int.parse(currentList[i] as String)) {
        update = true;
        break;
      }
    } catch (e) {
      Logger.root.severe('Error while comparing versions: $e');
      break;
    }
  }
  return update;
}
