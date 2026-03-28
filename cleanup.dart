import 'dart:io';

void main() {
  final file = File(
    r'c:\Users\seift\Documents\System Analysis\rideshare_app\lib\features\home\presentation\screens\home_screen.dart',
  );
  final lines = file.readAsLinesSync();

  // Lines 228 to 345 inclusive are lines to delete
  // indices 227 to 344
  final start_index = 227;
  final end_index = 345;

  final new_lines = [
    ...lines.sublist(0, start_index),
    ...lines.sublist(end_index),
  ];
  file.writeAsStringSync(new_lines.join('\n') + '\n');
  print('Deleted lines ${start_index + 1} to ${end_index}');
}
