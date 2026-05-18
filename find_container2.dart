import 'dart:io';

void main() {
  final dir = Directory('c:/axion_track_flutter/axion_track/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('Container(')) {
        // Collect next 10 lines
        String block = "";
        for (int j = i; j < i + 10 && j < lines.length; j++) {
          block += lines[j] + "\n";
        }
        
        // Remove 'BoxDecoration(color: ...)' or 'Icon(color: ...)' or 'Text(style: TextStyle(color: ...))'
        // to avoid false positives.
        String stripped = block.replaceAll(RegExp(r'BoxDecoration\s*\([^)]*\)'), '');
        stripped = stripped.replaceAll(RegExp(r'Icon\s*\([^)]*\)'), '');
        stripped = stripped.replaceAll(RegExp(r'TextStyle\s*\([^)]*\)'), '');
        stripped = stripped.replaceAll(RegExp(r'Text\s*\([^)]*\)'), '');
        stripped = stripped.replaceAll(RegExp(r'BorderSide\s*\([^)]*\)'), '');
        stripped = stripped.replaceAll(RegExp(r'BoxShadow\s*\([^)]*\)'), '');
        
        if (stripped.contains(RegExp(r'\bcolor:\s*')) && stripped.contains(RegExp(r'\bdecoration:\s*'))) {
          print('Found in ${file.path}:${i+1}\n$block\n---');
        }
      }
    }
  }
}
