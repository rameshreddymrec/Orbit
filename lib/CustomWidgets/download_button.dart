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

import 'package:orbit/APIs/api.dart';
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/Services/download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

class DownloadButton extends StatefulWidget {
  final Map data;
  final String? icon;
  final double? size;
  const DownloadButton({
    super.key,
    required this.data,
    this.icon,
    this.size,
  });

  @override
  _DownloadButtonState createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  late Download down;
  final Box downloadsBox = Hive.box('downloads');
  final ValueNotifier<bool> showStopButton = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    down = Download(widget.data['id'].toString());
    down.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 50,
      child: Center(
        child: (downloadsBox.containsKey(widget.data['id']))
            ? IconButton(
                icon: const Icon(Icons.download_done_rounded),
                tooltip: 'Download Done',
                color: Theme.of(context).colorScheme.secondary,
                iconSize: widget.size ?? 24.0,
                onPressed: () {
                  down.prepareDownload(context, widget.data);
                },
              )
            : down.progress == 0
                ? IconButton(
                    icon: Icon(
                      widget.icon == 'download'
                          ? Icons.download_rounded
                          : Icons.save_alt,
                    ),
                    iconSize: widget.size ?? 24.0,
                    color: Theme.of(context).iconTheme.color,
                    tooltip: 'Download',
                    onPressed: () {
                      down.prepareDownload(context, widget.data);
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      down.cancel();
                      setState(() {});
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 35,
                          width: 35,
                          child: CircularProgressIndicator(
                            value: down.progress == 1 ? null : down.progress,
                            strokeWidth: 3,
                          ),
                        ),
                        if (down.progress != null && down.progress! > 0 && down.progress! < 1)
                          Text(
                            '${(down.progress! * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        else
                          const Icon(Icons.close_rounded, size: 14),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class MultiDownloadButton extends StatefulWidget {
  final List data;
  final String playlistName;
  const MultiDownloadButton({
    super.key,
    required this.data,
    required this.playlistName,
  });

  @override
  _MultiDownloadButtonState createState() => _MultiDownloadButtonState();
}

class _MultiDownloadButtonState extends State<MultiDownloadButton> {
  late Download down;
  int done = 0;
  bool stopDownload = false;
  bool skipCurrent = false;
  bool running = false;

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    down = Download(widget.data.first['id'].toString());
    down.addListener(_updateState);
  }

  Future<void> _waitUntilDone(String id) async {
    while (down.lastDownloadId != id && !stopDownload && !skipCurrent && down.download) {
      await Future.delayed(const Duration(seconds: 1));
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox();
    }
    return SizedBox(
      width: 50,
      height: 50,
      child: Center(
        child: (down.lastDownloadId == widget.data.last['id'])
            ? IconButton(
                icon: const Icon(
                  Icons.download_done_rounded,
                ),
                color: Theme.of(context).colorScheme.secondary,
                iconSize: 25.0,
                tooltip: AppLocalizations.of(context)!.downDone,
                onPressed: () {},
              )
            : !running
                ? Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                      ),
                      iconSize: 25.0,
                      tooltip: AppLocalizations.of(context)!.down,
                      onPressed: () async {
                        setState(() {
                          running = true;
                        });
                        stopDownload = false;
                        for (final items in widget.data) {
                          if (stopDownload) break;
                          final songId = items['id'].toString();
                          final songDown = Download(songId);
                          
                          // Update bulk button to listen to current song
                          down.removeListener(_updateState);
                          down = songDown;
                          down.addListener(_updateState);
                          
                          down.download = true;
                          try {
                            down.prepareDownload(
                              context,
                              items as Map,
                              createFolder: true,
                              folderName: widget.playlistName,
                            );
                          } catch (e) {
                            Logger.root.severe('Error in prepareDownload: $e');
                          }
                          await _waitUntilDone(songId);
                          if (stopDownload) break;
                          if (skipCurrent || !down.download) {
                            Logger.root.info('Song skipped, moving to next');
                            skipCurrent = false;
                            setState(() {
                              done++;
                            });
                            continue;
                          }
                          setState(() {
                            done++;
                          });
                        }
                        if (stopDownload) {
                          setState(() {
                            done = 0;
                            running = false;
                          });
                        } else {
                          setState(() {
                            running = false;
                          });
                        }
                      },
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Skip current song, move to next
                          skipCurrent = true;
                          down.cancel();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(
                                value: down.progress == 1 ? null : down.progress,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(
                                value: done / widget.data.length,
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                              ),
                            ),
                            Text(
                              '${done + 1}/${widget.data.length}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              stopDownload = true;
                              down.cancel();
                              running = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class AlbumDownloadButton extends StatefulWidget {
  final String albumId;
  final String albumName;
  const AlbumDownloadButton({
    super.key,
    required this.albumId,
    required this.albumName,
  });

  @override
  _AlbumDownloadButtonState createState() => _AlbumDownloadButtonState();
}

class _AlbumDownloadButtonState extends State<AlbumDownloadButton> {
  late Download down;
  int done = 0;
  List data = [];
  bool finished = false;
  String currentSongTitle = '';
  bool stopDownload = false;
  bool skipCurrent = false;
  bool running = false;

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    down = Download(widget.albumId);
    down.addListener(_updateState);
  }

  Future<void> _waitUntilDone(String id) async {
    while (down.lastDownloadId != id && !stopDownload && !skipCurrent && down.download) {
      await Future.delayed(const Duration(seconds: 1));
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Center(
        child: finished
            ? IconButton(
                icon: const Icon(
                  Icons.download_done_rounded,
                ),
                color: Theme.of(context).colorScheme.secondary,
                iconSize: 25.0,
                tooltip: AppLocalizations.of(context)!.downDone,
                onPressed: () {},
              )
            : !running
                ? Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                      ),
                      iconSize: 25.0,
                      color: Theme.of(context).iconTheme.color,
                      tooltip: AppLocalizations.of(context)!.down,
                      onPressed: () async {
                        setState(() {
                          running = true;
                        });
                        stopDownload = false;
                        data = (await SaavnAPI()
                            .fetchAlbumSongs(widget.albumId))['songs'] as List;
                        for (final items in data) {
                          if (stopDownload) break;
                          final songId = items['id'].toString();
                          final songDown = Download(songId);

                          // Update bulk button to listen to current song
                          down.removeListener(_updateState);
                          down = songDown;
                          down.addListener(_updateState);

                          setState(() {
                            currentSongTitle = items['title'].toString();
                          });
                          down.download = true;
                          try {
                            down.prepareDownload(
                              context,
                              items as Map,
                              createFolder: true,
                              folderName: widget.albumName,
                            );
                          } catch (e) {
                            Logger.root.severe('Error in prepareDownload: $e');
                          }
                          await _waitUntilDone(songId);
                          if (stopDownload) break;
                          if (skipCurrent || !down.download) {
                            Logger.root.info('Song skipped, moving to next');
                            skipCurrent = false;
                            setState(() {
                              done++;
                            });
                            continue;
                          }
                          setState(() {
                            done++;
                          });
                        }
                        if (!stopDownload) {
                          finished = true;
                          setState(() {
                            running = false;
                          });
                        } else {
                          setState(() {
                            done = 0;
                            data = [];
                            currentSongTitle = '';
                            running = false;
                          });
                        }
                      },
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Skip current song, move to next
                          skipCurrent = true;
                          down.cancel();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(
                                value: down.progress == 1 ? null : down.progress,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(
                                value: data.isEmpty ? 0 : done / data.length,
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                              ),
                            ),
                            Text(
                              '${done + 1}/${data.isEmpty ? "?" : data.length}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              stopDownload = true;
                              down.cancel();
                              running = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
