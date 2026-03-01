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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore: avoid_classes_with_only_static_members
class ExtStorageProvider {
  // asking for permission
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      final result = await permission.request();
      if (result == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  // getting external storage path
  static Future<String?> getExtStorage({
    required String dirName,
    required bool writeAccess,
  }) async {
    Directory? directory;

    try {
      // checking platform
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        final int sdkInt = androidInfo.version.sdkInt;

        bool hasPermission = false;
        if (sdkInt >= 33) {
          hasPermission = await requestPermission(Permission.audio);
          // Also try manageExternalStorage if specifically needed for non-media folders, 
          // but for 'Music' Permission.audio might be enough depending on how it's used.
        } else {
          hasPermission = await requestPermission(Permission.storage);
        }

        if (hasPermission) {
          directory = await getExternalStorageDirectory();

          // getting main path (/storage/emulated/0)
          final String rootPath = directory!.path.split('/Android/data/')[0];
          final String newPath = '$rootPath/$dirName';

          directory = Directory(newPath);

          // checking if directory exist or not
          if (!await directory.exists()) {
            try {
              await directory.create(recursive: true);
            } catch (e) {
              // If fails, try asking for MANAGE_EXTERNAL_STORAGE for Android 11+
              if (sdkInt >= 30) {
                if (await requestPermission(Permission.manageExternalStorage)) {
                  await directory.create(recursive: true);
                } else {
                  // Fallback to app specific if all else fails? 
                  // Or let it throw to show the error.
                  rethrow;
                }
              } else {
                rethrow;
              }
            }
          }
          return newPath;
        } else {
          // Fallback check for MANAGE_EXTERNAL_STORAGE if legacy storage is denied
          if (sdkInt >= 30 && await requestPermission(Permission.manageExternalStorage)) {
            final String rootPath = '/storage/emulated/0';
            final directory = Directory('$rootPath/$dirName');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
            return directory.path;
          }
          throw 'Storage permission denied';
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        directory = await getApplicationDocumentsDirectory();
        final finalDirName = dirName.replaceAll('Orbit/', '');
        return '${directory.path}/$finalDirName';
      } else {
        directory = await getDownloadsDirectory();
        return '${directory!.path}/$dirName';
      }
    } catch (e) {
      rethrow;
    }
  }
}
