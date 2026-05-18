import 'dart:io';

void main() {
  final dir = Directory('c:/axion_track_flutter/axion_track/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    final content = file.readAsStringSync();
    // A simple regex to find Container(...) where both color: and decoration: exist inside the parentheses
    // This is a bit tricky, but we can just find 'Container(' and scan until the matching ')'
    
    int index = 0;
    while (true) {
      index = content.indexOf('Container(', index);
      if (index == -1) break;
      
      int start = index;
      int parenCount = 0;
      int i = start + 9; // at '('
      bool found = false;
      
      while (i < content.length) {
        if (content[i] == '(') parenCount++;
        else if (content[i] == ')') {
          parenCount--;
          if (parenCount == 0) {
            found = true;
            break;
          }
        }
        i++;
      }
      
      if (found) {
        final containerBody = content.substring(start, i + 1);
        
        // Check if color: and decoration: are top-level properties within this Container
        // We'll just do a rough check first: if it contains "color:" and "decoration:"
        if (containerBody.contains(RegExp(r'\bcolor:')) && containerBody.contains(RegExp(r'\bdecoration:'))) {
          // Verify they are not nested. We can just print and manually inspect.
          print('Found in ${file.path}:\n$containerBody\n---');
        }
      }
      index = i;
    }
  }
}
