import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/media_scanner.dart';

class RenameDialog extends StatefulWidget {
  final MediaFile file;

  const RenameDialog({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;
  String? _errorText;
  late String _extension;

  @override
  void initState() {
    super.initState();
    final parts = widget.file.path.split('.');
    _extension = parts.isNotEmpty ? parts.last : "";
    _controller = TextEditingController(text: widget.file.title);
    
    // Position cursor at the end
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String val) {
    // Check for invalid file name characters on Windows/Android
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    if (val.trim().isEmpty) {
      setState(() {
        _errorText = "Name cannot be empty";
      });
    } else if (invalidChars.hasMatch(val)) {
      setState(() {
        _errorText = "Invalid characters: \\ / : * ? \" < > |";
      });
    } else {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PulseColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text("Rename File", style: PulseTypography.displaySmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: _validate,
            autofocus: true,
            style: PulseTypography.bodyLarge,
            decoration: InputDecoration(
              filled: true,
              fillColor: PulseColors.surface,
              errorText: _errorText,
              errorStyle: TextStyle(color: PulseColors.danger),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PulseColors.accentPrimary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2C2C42)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PulseColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: PulseColors.danger),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ".$_extension",
            style: PulseTypography.monoLabel.copyWith(color: PulseColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _errorText == null && _controller.text.trim().isNotEmpty
              ? () async {
                  final newName = _controller.text.trim();
                  Navigator.pop(context);
                  await MediaScanner.instance.renameMediaFile(widget.file, newName);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: PulseColors.accentPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Rename"),
        ),
      ],
    );
  }
}
