import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';

IconData iconForFile(TrackedFile f) {
  if (f.isDir) return Icons.folder_outlined;
  return switch (f.extension) {
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' || 'svg' =>
      Icons.image_outlined,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' => Icons.movie_outlined,
    'mp3' || 'wav' || 'flac' || 'ogg' || 'm4a' => Icons.music_note_outlined,
    'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' || 'odt' || 'rtf' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' || 'ods' => Icons.table_chart_outlined,
    'ppt' || 'pptx' => Icons.slideshow_outlined,
    'exe' || 'msi' || 'deb' || 'rpm' || 'appimage' || 'dmg' =>
      Icons.apps_outlined,
    'dart' || 'py' || 'js' || 'ts' || 'java' || 'c' || 'cpp' || 'go' ||
    'rs' || 'sh' =>
      Icons.code_outlined,
    'torrent' => Icons.download_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

/// One row in the review list: icon, name+path, size/time, keep checkbox.
class FileTile extends StatelessWidget {
  final TrackedFile file;
  final bool keep;
  final ValueChanged<bool> onKeepChanged;

  const FileTile({
    super.key,
    required this.file,
    required this.keep,
    required this.onKeepChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onKeepChanged(!keep),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                iconForFile(file),
                size: 22,
                color: file.isDir
                    ? CeColors.warning.withValues(alpha: 0.8)
                    : CeColors.accent.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: CeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: file.path,
                      child: Text(
                        file.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CeText.mono(
                          size: 11,
                          color: CeColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _tag(file.rootLabel),
                        const SizedBox(width: 6),
                        _tag(file.origin.label),
                        const SizedBox(width: 8),
                        Text(
                          formatTime(file.modified),
                          style: CeText.mono(
                            size: 11,
                            color: CeColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                file.isDir ? '—' : formatBytes(file.sizeBytes),
                style: CeText.mono(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: CeColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Checkbox(
                    value: keep,
                    onChanged: (v) => onKeepChanged(v ?? false),
                  ),
                  const Text(
                    'keep',
                    style: TextStyle(
                      fontSize: 10,
                      color: CeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: CeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: CeColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          color: CeColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
