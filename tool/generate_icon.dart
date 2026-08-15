import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _size = 256;

void main() {
  final int pixelBytes = _size * _size * 4;
  final int maskBytes = (_size ~/ 8 + 3) ~/ 4 * 4 * _size;
  final int imageBytes = 40 + pixelBytes + maskBytes;
  final ByteData data = ByteData(22 + imageBytes);
  int offset = 0;

  void u16(int value) {
    data.setUint16(offset, value, Endian.little);
    offset += 2;
  }

  void u32(int value) {
    data.setUint32(offset, value, Endian.little);
    offset += 4;
  }

  u16(0);
  u16(1);
  u16(1);
  data.setUint8(offset++, 0);
  data.setUint8(offset++, 0);
  data.setUint8(offset++, 0);
  data.setUint8(offset++, 0);
  u16(1);
  u16(32);
  u32(imageBytes);
  u32(22);

  u32(40);
  u32(_size);
  u32(_size * 2);
  u16(1);
  u16(32);
  u32(0);
  u32(pixelBytes);
  u32(3780);
  u32(3780);
  u32(0);
  u32(0);

  for (int fileY = 0; fileY < _size; fileY++) {
    final int y = _size - 1 - fileY;
    for (int x = 0; x < _size; x++) {
      final ({int r, int g, int b, int a}) color = _pixel(x, y);
      data.setUint8(offset++, color.b);
      data.setUint8(offset++, color.g);
      data.setUint8(offset++, color.r);
      data.setUint8(offset++, color.a);
    }
  }
  while (offset < data.lengthInBytes) {
    data.setUint8(offset++, 0);
  }
  File(
    'windows/runner/resources/app_icon.ico',
  ).writeAsBytesSync(data.buffer.asUint8List(), flush: true);
  _writePng('web/favicon.png', 64);
  _writePng('web/icons/Icon-192.png', 192);
  _writePng('web/icons/Icon-512.png', 512);
  _writePng('web/icons/Icon-maskable-192.png', 192, maskable: true);
  _writePng('web/icons/Icon-maskable-512.png', 512, maskable: true);
}

void _writePng(String path, int size, {bool maskable = false}) {
  final BytesBuilder scanlines = BytesBuilder(copy: false);
  final double artworkScale = maskable ? 0.82 : 1;
  for (int y = 0; y < size; y++) {
    scanlines.addByte(0);
    for (int x = 0; x < size; x++) {
      final double sourceX =
          127.5 + (x + 0.5 - size / 2) * 256 / size / artworkScale;
      final double sourceY =
          127.5 + (y + 0.5 - size / 2) * 256 / size / artworkScale;
      final ({int r, int g, int b, int a}) color = _pixel(sourceX, sourceY);
      scanlines.add(<int>[color.r, color.g, color.b, color.a]);
    }
  }

  final BytesBuilder png = BytesBuilder(copy: false)
    ..add(const <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  final ByteData header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _addPngChunk(png, 'IHDR', header.buffer.asUint8List());
  _addPngChunk(png, 'IDAT', ZLibEncoder().convert(scanlines.takeBytes()));
  _addPngChunk(png, 'IEND', const <int>[]);
  final File output = File(path);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(png.takeBytes(), flush: true);
}

void _addPngChunk(BytesBuilder output, String type, List<int> content) {
  final List<int> typeBytes = ascii.encode(type);
  final ByteData length = ByteData(4)..setUint32(0, content.length);
  output
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(content);
  final ByteData checksum = ByteData(4)
    ..setUint32(0, _crc32(<int>[...typeBytes, ...content]));
  output.add(checksum.buffer.asUint8List());
}

int _crc32(List<int> bytes) {
  int crc = 0xffffffff;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

({int r, int g, int b, int a}) _pixel(num x, num y) {
  final double dx = x - 127.5;
  final double dy = y - 127.5;
  final double radius = math.sqrt(dx * dx + dy * dy);
  const ({int r, int g, int b, int a}) background = (
    r: 8,
    g: 17,
    b: 14,
    a: 255,
  );
  const ({int r, int g, int b, int a}) surface = (r: 18, g: 32, b: 27, a: 255);
  const ({int r, int g, int b, int a}) gold = (r: 214, g: 178, b: 94, a: 255);
  const ({int r, int g, int b, int a}) green = (r: 46, g: 155, b: 104, a: 255);
  const ({int r, int g, int b, int a}) cream = (r: 244, g: 241, b: 232, a: 255);
  if (radius > 112) {
    return background;
  }
  if (radius > 103 || (radius > 82 && radius < 87)) {
    return gold;
  }
  if (radius < 41) {
    return radius > 35 ? cream : green;
  }
  final double angle = math.atan2(dy, dx);
  final double segment = ((angle + math.pi) / (2 * math.pi) * 37) % 1;
  if ((segment - 0.5).abs() > 0.44 && radius > 48) {
    return gold;
  }
  return surface;
}
