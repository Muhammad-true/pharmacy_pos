import 'dart:io';

import 'package:logger/logger.dart';

class FileLogOutput extends LogOutput {
  final File logFile;

  FileLogOutput(this.logFile);

  @override
  void output(OutputEvent event) {
    if (event.lines.isEmpty) return;
    try {
      logFile.parent.createSync(recursive: true);
      final buffer = StringBuffer();
      for (final line in event.lines) {
        buffer.writeln(line);
      }
      logFile.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Не падаем при ошибке записи лога
    }
  }
}

