import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class LocalFileService {
  const LocalFileService();

  Future<({String name, String content})?> openImportFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Roulette Lab-data',
      extensions: <String>['json', 'csv', 'txt'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null) {
      return null;
    }
    return (name: file.name, content: await file.readAsString());
  }

  Future<bool> saveText({
    required String suggestedName,
    required String content,
    required String mimeType,
  }) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
    );
    if (location == null) {
      return false;
    }
    final XFile file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return true;
  }
}
