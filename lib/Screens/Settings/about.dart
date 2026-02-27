import 'dart:io';
import 'dart:ui';

import 'package:orbit/CustomWidgets/copy_clipboard.dart';
import 'package:orbit/CustomWidgets/gradient_containers.dart';
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/Helpers/github.dart';
import 'package:orbit/Helpers/update.dart';
import 'package:orbit/Helpers/update_helper.dart';
import 'package:orbit/globals.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.about,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          iconTheme: IconThemeData(
            color: Theme.of(context).iconTheme.color,
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/orbit_logo_new.png',
                    width: 110,
                    height: 110,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Orbit',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'v ${AppGlobals.appVersion}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.bodySmall!.color,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.version,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.versionSub,
              ),
              trailing: Text(
                'v${AppGlobals.appVersion}',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
              onTap: () {
                ShowSnackBar().showSnackBar(
                  context,
                  AppLocalizations.of(context)!.checkingUpdate,
                  noAction: true,
                );
                GitHub.getLatestRelease().then((Map release) async {
                  final String? latestVersion = release['version'] as String?;
                  final String? changelog = release['changelog'] as String?;
                  final bool isForce = release['isForce'] as bool? ?? false;
                  if (latestVersion != null &&
                      compareVersion(latestVersion, AppGlobals.appVersion!)) {
                    if (mounted) {
                      UpdateHelper.showUpdateDialog(
                        context: context,
                        version: latestVersion,
                        changelog: changelog,
                        isForce: isForce,
                      );
                    }
                  } else {
                    ShowSnackBar().showSnackBar(
                      context,
                      AppLocalizations.of(context)!.latest,
                    );
                  }
                });
              },
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.shareApp,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.shareAppSub,
              ),
              onTap: () {
                Share.share(
                  'Hey! Check out Orbit — the definitive music experience: https://orbitmusicapp.framer.website/',
                );
              },
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.donateGpay,
              ),
              subtitle: const Text(
                'kamireddyrameshreddy@finobank',
              ),
              onTap: () {
                launchUrl(
                  Uri.parse(
                    'upi://pay?pa=kamireddyrameshreddy@finobank&pn=Orbit',
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.contactUs,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.contactUsSub,
              ),
              onTap: () => launchUrl(
                Uri.parse('mailto:kamireddyramesh0527@gmail.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              AppLocalizations.of(context)!.madeBy,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall!.color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
