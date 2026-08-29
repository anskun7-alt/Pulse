import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/metadata_service.dart';
import '../services/media_scanner.dart';

class TagEditorSheet extends StatefulWidget {
  final MediaFile file;

  const TagEditorSheet({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _yearController;
  late TextEditingController _genreController;
  late TextEditingController _trackController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.file.title);
    _artistController = TextEditingController(text: widget.file.artist);
    _albumController = TextEditingController(text: widget.file.album);
    
    // For other fields, try to read file properties or defaults
    _yearController = TextEditingController(text: "2026");
    _genreController = TextEditingController(text: "Audio");
    _trackController = TextEditingController(text: "1");
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  Future<void> _saveTags() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await MetadataService.instance.writeTags(
        widget.file.path,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
        year: _yearController.text.trim(),
        genre: _genreController.text.trim(),
        trackNumber: _trackController.text.trim(),
      );

      if (success) {
        // Trigger a pull rescan or just manually update cache of this file
        await MediaScanner.instance.scan(); // Safe fallback to update cache
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Tags saved successfully"),
              backgroundColor: PulseColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Tagger execution failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to write tags on disk: $e"),
            backgroundColor: PulseColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset + 20 : 24,
      ),
      decoration: BoxDecoration(
        color: PulseColors.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Edit Track Info", style: PulseTypography.displayMedium),
                  _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PulseColors.accentPrimary),
                        )
                      : TextButton(
                          onPressed: _saveTags,
                          child: Text(
                            "Save",
                            style: PulseTypography.bodyLarge.copyWith(
                              color: PulseColors.accentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 16),
              // Album art change placeholder
              Center(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: widget.file.albumArtPath != null && File(widget.file.albumArtPath!).existsSync()
                          ? Image.file(
                              File(widget.file.albumArtPath!),
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 140,
                              height: 140,
                              color: PulseColors.surface,
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 48,
                                color: PulseColors.accentPrimary,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: PulseColors.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField("Title", _titleController, (v) => v!.isEmpty ? "Title is required" : null),
              const SizedBox(height: 16),
              _buildTextField("Artist", _artistController, (v) => v!.isEmpty ? "Artist is required" : null),
              const SizedBox(height: 16),
              _buildTextField("Album", _albumController, (v) => v!.isEmpty ? "Album is required" : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField("Year", _yearController, null)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Track #", _trackController, null)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField("Genre", _genreController, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? Function(String?)? validator,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: PulseTypography.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: PulseColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulseColors.accentPrimary, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E30), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulseColors.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PulseColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
