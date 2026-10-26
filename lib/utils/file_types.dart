import 'package:flutter/material.dart';

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

IconData iconForFileName(String name) => switch (_extensionOf(name)) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'txt' || 'md' || 'log' => Icons.description_outlined,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => Icons.image_outlined,
      'zip' || 'rar' || '7z' || 'gz' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

/// Content type to store with an upload, or null when the extension
/// isn't one we know (the server then treats it as a generic binary).
String? mimeTypeForName(String name) => switch (_extensionOf(name)) {
      'pdf' => 'application/pdf',
      'txt' || 'log' => 'text/plain',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'json' => 'application/json',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'zip' => 'application/zip',
      _ => null,
    };
