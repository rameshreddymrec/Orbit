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

import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/empty_screen.dart';
import 'package:orbit/CustomWidgets/drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Stats extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const Stats({super.key, this.scaffoldKey});

  @override
  State<Stats> createState() => _StatsState();
}

class _StatsState extends State<Stats> {
  List<Map> topSongs = [];
  Map<String, int> topArtists = {};
  int totalSongsPlayed = 0;
  int totalPlayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final box = Hive.box('stats');
    final Map<dynamic, dynamic> rawMap = box.toMap();
    
    // Filter out non-song keys (like 'mostPlayed')
    final List<Map> allSongs = [];
    final Map<String, int> artistCounts = {};
    int songsCount = 0;
    int playsCount = 0;

    rawMap.forEach((key, value) {
      if (key != 'mostPlayed' && value is Map) {
        allSongs.add(value);
        songsCount++;
        final playCount = (value['playCount'] as int?) ?? 0;
        playsCount += playCount;

        // Aggregate artists
        final artist = value['artist'] as String?;
        if (artist != null && artist.isNotEmpty) {
          // Handle multiple artists if separated by comma or just take the first
          final mainArtist = artist.split(',').first.trim(); 
          artistCounts[mainArtist] = (artistCounts[mainArtist] ?? 0) + playCount;
        }
      }
    });

    // Sort songs by play count
    allSongs.sort((a, b) {
      final int playCountA = (a['playCount'] as int?) ?? 0;
      final int playCountB = (b['playCount'] as int?) ?? 0;
      return playCountB.compareTo(playCountA);
    });

    setState(() {
      topSongs = allSongs.take(10).toList();
      topArtists = Map.fromEntries(
        artistCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
      );
      totalSongsPlayed = songsCount;
      totalPlayCount = playsCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool rotated = MediaQuery.sizeOf(context).height < screenWidth;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          AppLocalizations.of(context)!.stats,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: rotated ? null : homeDrawer(context: context, scaffoldKey: widget.scaffoldKey),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 10),
          ),
          if (totalSongsPlayed == 0)
            SliverFillRemaining(
              child: emptyScreen(
                context,
                3,
                AppLocalizations.of(context)!.nothingTo,
                15.0,
                AppLocalizations.of(context)!.showHere,
                50.0,
                AppLocalizations.of(context)!.playSomething,
                23.0,
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSummaryCards(context),
                  const SizedBox(height: 20),
                  if (topArtists.isNotEmpty) _buildTopArtistsChart(context),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                    child: Text(
                      AppLocalizations.of(context)!.mostPlayedSong,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = topSongs[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: 50,
                        width: 50,
                        child: CachedNetworkImage(
                          fit: BoxFit.cover,
                          errorWidget: (context, _, __) => const Image(
                            fit: BoxFit.cover,
                            image: AssetImage('assets/cover.jpg'),
                          ),
                          imageUrl: song['image'].toString().replaceAll('http:', 'https:'),
                          placeholder: (context, url) => const Image(
                            fit: BoxFit.cover,
                            image: AssetImage('assets/cover.jpg'),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      song['title'].toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      song['artist'].toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${song['playCount']} plays',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                childCount: topSongs.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              context,
              AppLocalizations.of(context)!.songsPlayed,
              totalPlayCount.toString(),
              CupertinoIcons.music_note_2,
              Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard(
              context,
              'Unique Songs', // Placeholder for localization or add key
              totalSongsPlayed.toString(),
              CupertinoIcons.music_albums,
              Colors.purpleAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtistsChart(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.purple,
    ];

    final top5 = topArtists.entries.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.chart_pie_fill, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Top Artists', // Localization needed ideally
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: List.generate(top5.length, (i) {
                    final isTouched = false; // Add interactivity later if needed
                    final fontSize = isTouched ? 16.0 : 12.0;
                    final radius = isTouched ? 60.0 : 50.0;
                    final entry = top5[i];
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entry.value.toDouble(),
                      title: '${((entry.value / totalPlayCount) * 100).toStringAsFixed(0)}%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: List.generate(top5.length, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors[i % colors.length],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          top5[i].key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${top5[i].value} plays',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
