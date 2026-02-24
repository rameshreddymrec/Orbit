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
import 'package:orbit/CustomWidgets/glass_box.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/image_card.dart';
import 'package:orbit/Screens/Player/audioplayer.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MiniPlayer extends StatefulWidget {
  static const MiniPlayer _instance = MiniPlayer._internal();

  factory MiniPlayer() {
    return _instance;
  }

  const MiniPlayer._internal();

  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  late List preferredMiniButtons;
  late bool useDense;

  @override
  void initState() {
    super.initState();
    preferredMiniButtons = Hive.box('settings').get(
      'preferredMiniButtons',
      defaultValue: ['Like', 'Play/Pause', 'Next'],
    )?.toList() as List;
    useDense = Hive.box('settings').get(
      'useDenseMini',
      defaultValue: false,
    ) as bool;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool rotated = screenHeight < screenWidth;

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box box, _) {
        preferredMiniButtons = box.get(
          'preferredMiniButtons',
          defaultValue: ['Like', 'Play/Pause', 'Next'],
        )?.toList() as List;
        useDense = box.get(
          'useDenseMini',
          defaultValue: false,
        ) as bool || rotated;

        return StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final MediaItem? mediaItem = snapshot.data;
            final bool isLocal =
                mediaItem?.artUri?.toString().startsWith('file:') ?? false;

            return Dismissible(
            key: const Key('miniplayer'),
            direction: DismissDirection.up,
            background: const SizedBox.shrink(),
            confirmDismiss: (DismissDirection direction) {
              if (mediaItem != null) {
                if (direction == DismissDirection.down) {
                  audioHandler.stop();
                } else {
                  Navigator.pushNamed(context, '/player');
                }
              }
              return Future.value(false);
            },
            dismissThresholds: const {
              DismissDirection.up: 0.1,
            },
            child: Dismissible(
              key: Key(mediaItem?.id ?? 'nothingPlaying'),
              background: const SizedBox.shrink(),
              confirmDismiss: (DismissDirection direction) {
                if (mediaItem != null) {
                  if (direction == DismissDirection.startToEnd) {
                    audioHandler.skipToPrevious();
                  } else {
                    audioHandler.skipToNext();
                  }
                }
                return Future.value(false);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    miniplayerTile(
                      context: context,
                      preferredMiniButtons: preferredMiniButtons,
                      useDense: useDense,
                      title: mediaItem?.title ?? '',
                      subtitle: mediaItem?.artist ?? '',
                      imagePath: (isLocal
                              ? mediaItem?.artUri?.toFilePath()
                              : mediaItem?.artUri?.toString()) ??
                          '',
                      isLocalImage: isLocal,
                      isDummy: mediaItem == null,
                    ),
                    positionSlider(
                      mediaItem?.duration?.inSeconds.toDouble(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget miniplayerTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imagePath,
    required List preferredMiniButtons,
    bool useDense = false,
    bool isLocalImage = false,
    bool isDummy = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: isDummy
          ? null
          : () {
              Navigator.pushNamed(context, '/player');
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            Hero(
              tag: 'currentArtwork',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: SizedBox(
                  width: useDense ? 45.0 : 50.0,
                  height: useDense ? 45.0 : 50.0,
                  child: imageCard(
                    elevation: 0,
                    boxDimension: useDense ? 45.0 : 50.0,
                    localImage: isLocalImage,
                    imageUrl: imagePath,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDummy ? 'Now Playing' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    isDummy ? 'Unknown' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (!isDummy)
              ControlButtons(
                audioHandler,
                miniplayer: true,
                buttons: ['Like', 'Play/Pause', 'Next'],
              ),
          ],
        ),
      ),
    );
  }

  StreamBuilder<Duration> positionSlider(double? maxDuration) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final double currentPos = position?.inMilliseconds.toDouble() ?? 0.0;
        final double totalDuration = (maxDuration ?? 180.0) * 1000;

        return (currentPos < 0.0 || currentPos > totalDuration)
            ? const SizedBox()
            : SizedBox(
                height: 2,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.linear,
                  tween: Tween<double>(
                    end: (totalDuration == 0) ? 0.0 : currentPos / totalDuration,
                  ),
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  },
                ),
              );
      },
    );
  }
}
