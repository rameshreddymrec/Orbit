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

import 'package:orbit/CustomWidgets/copy_clipboard.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-decode fallback just in case, but usually handled in main.dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/orbit_logo_new.png'),
        context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double separationHeight = MediaQuery.sizeOf(context).height * 0.035;

    return GradientContainer(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.transparent
              : Theme.of(context).colorScheme.secondary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppLocalizations.of(context)!.about,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  Image(
                    image: const AssetImage('assets/orbit_logo_new.png'),
                    width: 110,
                    height: 110,
                    gaplessPlayback: true,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Orbit',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('v ${AppGlobals.appVersion}'),
                ],
              ),
              SizedBox(
                height: separationHeight,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.aboutLine1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Share.share(
                            'Check out Orbit: https://orbitmusicapp.framer.website/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22FF88),
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: Text(AppLocalizations.of(context)!.shareApp),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: separationHeight,
              ),
              Column(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.transparent,
                    ),
                    onPressed: () {
                      const String upiUrl =
                          'upi://pay?pa=kamireddyrameshreddy@finobank&pn=Orbit';
                      launchUrl(
                        Uri.parse(upiUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    onLongPress: () {
                      copyToClipboard(
                        context: context,
                        text: 'kamireddyrameshreddy@finobank',
                        displayText: AppLocalizations.of(
                          context,
                        )!
                            .upiCopied,
                      );
                    },
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width / 1.5,
                      child: Image(
                        image: AssetImage(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/gpay-white.png'
                              : 'assets/gpay-white.png',
                        ),
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.sponsor,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: separationHeight,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.madeBy,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
