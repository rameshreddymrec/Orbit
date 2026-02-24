import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orbit/CustomWidgets/snackbar.dart';
import 'package:orbit/Helpers/github.dart';
import 'package:orbit/Helpers/update.dart';

class UpdateHelper {
  static void showUpdateDialog({
    required BuildContext context,
    required String version,
    String? changelog,
    bool isForce = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) {
        double progress = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async => !isForce,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.updateAvailable,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v$version is ready to download.\nBetter performance & features.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (changelog != null && changelog.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const Text(
                        "What's New:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Text(
                            changelog,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .color!
                                  .withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (progress > 0) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          '${(progress * 100).toInt()}% downloaded',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (progress == 0 && !isForce)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context)!.later,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  if (progress == 0)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        setDialogState(() {
                          progress = 0.001; // Start progress
                        });
                        try {
                          final Map release = await GitHub.getLatestRelease();
                          final String? downloadUrl =
                              release['downloadUrl'] as String?;
                          if (downloadUrl != null) {
                            await Updater.downloadAndInstall(
                              downloadUrl,
                              version,
                              onProgress: (p) {
                                setDialogState(() {
                                  progress = p;
                                });
                              },
                            );
                          } else {
                            throw Exception('No APK found in release assets.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ShowSnackBar().showSnackBar(
                              context,
                              'Update failed: $e',
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Update Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
