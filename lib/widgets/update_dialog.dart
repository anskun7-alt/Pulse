import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo release;
  final String currentVersion;

  const UpdateDialog({
    Key? key,
    required this.release,
    required this.currentVersion,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  bool _isInstalled = false;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    UpdateService.instance.downloadAndInstall(
      release: widget.release,
      onProgress: (progress, downloaded, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _downloadedBytes = downloaded;
            _totalBytes = total;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = error;
          });
        }
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isInstalled = true;
          });
        }
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PulseColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: PulseColors.accentPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon & title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PulseColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    color: PulseColors.accentPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Update Available',
                        style: PulseTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion}  ➔  ${widget.release.tagName}',
                        style: PulseTypography.monoLabel.copyWith(
                          color: PulseColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Release title & Changelog section
            Text(
              widget.release.title,
              style: PulseTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PulseColors.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.release.changelog.trim(),
                  style: PulseTypography.bodyMedium.copyWith(
                    color: PulseColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PulseColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: PulseColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: PulseTypography.bodySmall.copyWith(color: PulseColors.danger),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Downloading progress bar
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading update...',
                        style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
                      ),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}% (${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)})',
                        style: PulseTypography.monoLabel.copyWith(
                          color: PulseColors.accentPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: PulseColors.background,
                      color: PulseColors.accentPrimary,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: PulseColors.textSecondary,
                    ),
                    child: const Text('Later'),
                  ),
                const SizedBox(width: 8),
                if (!_isDownloading && !_isInstalled) ...[
                  ElevatedButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulseColors.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else if (_isInstalled) ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  IconButton(
                    tooltip: 'Open in browser',
                    icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70),
                    onPressed: () => launchUrl(
                      Uri.parse(widget.release.htmlUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
