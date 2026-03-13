import 'dart:io';
import 'dart:typed_data';

// Minimal PNG encoder for a solid-color 1024x1024 image
void main() {
  final width = 1024;
  final height = 1024;
  
  // Build raw RGBA pixel data (red)
  final rawPixels = Uint8List(height * (1 + width * 4)); // filter byte + RGBA per pixel per row
  var offset = 0;
  for (var y = 0; y < height; y++) {
    rawPixels[offset++] = 0; // filter: None
    for (var x = 0; x < width; x++) {
      rawPixels[offset++] = 255; // R
      rawPixels[offset++] = 0;   // G
      rawPixels[offset++] = 0;   // B
      rawPixels[offset++] = 255; // A
    }
  }

  // Compress with zlib
  final compressed = zlib.encode(rawPixels);

  // Build PNG
  final png = BytesBuilder();
  
  // Signature
  png.add([137, 80, 78, 71, 13, 10, 26, 10]);
  
  // IHDR
  final ihdr = BytesBuilder();
  ihdr.add(_uint32(width));
  ihdr.add(_uint32(height));
  ihdr.add([8, 6, 0, 0, 0]); // 8-bit RGBA
  _writeChunk(png, 'IHDR', ihdr.toBytes());
  
  // IDAT
  _writeChunk(png, 'IDAT', Uint8List.fromList(compressed));
  
  // IEND
  _writeChunk(png, 'IEND', Uint8List(0));
  
  File('assets/test_icon.png').writeAsBytesSync(png.toBytes());
  print('Created assets/test_icon.png');
}

Uint8List _uint32(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

void _writeChunk(BytesBuilder png, String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  png.add(_uint32(data.length));
  png.add(typeBytes);
  png.add(data);
  
  // CRC32
  final crcData = Uint8List(4 + data.length);
  crcData.setAll(0, typeBytes);
  crcData.setAll(4, data);
  png.add(_uint32(_crc32(crcData)));
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (var byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if (crc & 1 != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
