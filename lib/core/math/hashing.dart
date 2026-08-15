String historyFingerprint(Iterable<int> numbers, {String settingsKey = ''}) {
  int hash = 0x811c9dc5;
  void addByte(int value) {
    hash ^= value & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }

  int count = 0;
  for (final int number in numbers) {
    addByte(number);
    addByte(count & 0xff);
    addByte((count >> 8) & 0xff);
    count++;
  }
  for (final int unit in settingsKey.codeUnits) {
    addByte(unit);
  }
  addByte(count & 0xff);
  addByte((count >> 8) & 0xff);
  return hash.toRadixString(16).padLeft(8, '0');
}
