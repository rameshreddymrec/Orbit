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

import 'package:audio_service/audio_service.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/popup.dart';
import 'package:orbit/Helpers/mediaitem_converter.dart';
import 'package:flutter/material.dart';

void showSongInfo(MediaItem mediaItem, BuildContext context) {
  final Map rawDetails = MediaItemConverter.mediaItemToMap(mediaItem);

  // Format duration as MM:SS
  try {
    final int secs = int.parse(rawDetails['duration'].toString());
    rawDetails['duration'] =
        '${(secs ~/ 60).toString().padLeft(2, "0")}:${(secs % 60).toString().padLeft(2, "0")}';
  } catch (_) {}

  // Only show user-friendly fields in a clean order
  const List<String> orderedKeys = [
    'title',
    'artist',
    'album',
    'year',
    'release_date',
    'language',
    'duration',
    'subtitle',
  ];

  final Map details = {};
  for (final key in orderedKeys) {
    final val = rawDetails[key];
    if (val != null &&
        val.toString().trim().isNotEmpty &&
        val.toString() != 'null') {
      details[key] = val;
    }
  }

  // For offline songs also show file info
  if (mediaItem.extras?['size'] != null) {
    try {
      details['date_modified'] = DateTime.fromMillisecondsSinceEpoch(
        int.parse(mediaItem.extras!['date_modified'].toString()) * 1000,
      ).toString().split('.').first;
      details['size'] =
          '${((mediaItem.extras!['size'] as int) / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (_) {}
  }

  PopupDialog().showPopup(
    context: context,
    child: GradientCard(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details.keys.map((e) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 10.0,
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text:
                          '${e[0].toUpperCase()}${e.substring(1)}\n'.replaceAll(
                        '_',
                        ' ',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall!.color,
                      ),
                    ),
                    TextSpan(
                      text: details[e].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                showCursor: true,
                cursorColor: Colors.black,
                cursorRadius: const Radius.circular(5),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

