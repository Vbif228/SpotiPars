import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/track_item.dart';

class Id3Tagger {
  final http.Client _client;

  Id3Tagger({http.Client? client}) : _client = client ?? http.Client();

  /// Downloads cover art image as bytes.
  Future<Uint8List?> fetchCoverBytes(String coverUrl) async {
    if (coverUrl.isEmpty) return null;
    try {
      final res = await _client.get(Uri.parse(coverUrl)).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Injects ID3v2.3 metadata (Title, Artist, Album, Track No, and JPEG APIC Cover)
  /// into an MP3 file using pure Dart.
  Future<void> tagMp3File(
    File audioFile,
    TrackItem track, {
    Uint8List? coverBytes,
  }) async {
    if (!await audioFile.exists()) return;

    coverBytes ??= await fetchCoverBytes(track.coverUrl);

    final rawAudioBytes = await audioFile.readAsBytes();

    // Guard against corrupting non-MP3 containers (MP4/M4A/AAC and WebM/Opus).
    // Prepending raw ID3v2 tags to an MP4 container displaces the 'ftyp' atom and
    // invalidates the 'stco' chunk offset table, rendering the file unplayable.
    if (rawAudioBytes.length >= 8) {
      final isMp4 = rawAudioBytes[4] == 0x66 && // 'f'
          rawAudioBytes[5] == 0x74 && // 't'
          rawAudioBytes[6] == 0x79 && // 'y'
          rawAudioBytes[7] == 0x70; // 'p'
      final isWebM = rawAudioBytes[0] == 0x1A &&
          rawAudioBytes[1] == 0x45 &&
          rawAudioBytes[2] == 0xDF &&
          rawAudioBytes[3] == 0xA3;
      if (isMp4 || isWebM) {
        // Container is MP4 or WebM; keep container byte integrity intact.
        return;
      }
    }

    // Check if file already has an ID3v2 tag at the start and strip it
    int audioStartIndex = 0;
    if (rawAudioBytes.length >= 10 &&
        rawAudioBytes[0] == 0x49 && // 'I'
        rawAudioBytes[1] == 0x44 && // 'D'
        rawAudioBytes[2] == 0x33) { // '3'
      final tagSize = _decodeSynchsafeInt(
        rawAudioBytes[6],
        rawAudioBytes[7],
        rawAudioBytes[8],
        rawAudioBytes[9],
      );
      audioStartIndex = 10 + tagSize;
      if (audioStartIndex > rawAudioBytes.length) {
        audioStartIndex = 0;
      }
    }

    final cleanAudioData = audioStartIndex > 0
        ? rawAudioBytes.sublist(audioStartIndex)
        : rawAudioBytes;

    final id3v2Block = _buildId3v23TagBlock(
      title: track.title,
      artist: track.artist,
      album: track.album,
      trackNumber: track.trackNumber,
      coverBytes: coverBytes,
    );

    final output = BytesBuilder(copy: false)
      ..add(id3v2Block)
      ..add(cleanAudioData);

    await audioFile.writeAsBytes(output.takeBytes(), flush: true);
  }

  // --- ID3v2.3 Builder Helpers ---

  Uint8List _buildId3v23TagBlock({
    required String title,
    required String artist,
    required String album,
    required int trackNumber,
    Uint8List? coverBytes,
  }) {
    final framesBuilder = BytesBuilder();

    // Text frames encoded in UTF-16 with BOM (encoding byte 0x01)
    if (title.isNotEmpty) {
      framesBuilder.add(_buildTextFrame('TIT2', title));
    }
    if (artist.isNotEmpty) {
      framesBuilder.add(_buildTextFrame('TPE1', artist));
    }
    if (album.isNotEmpty) {
      framesBuilder.add(_buildTextFrame('TALB', album));
    }
    framesBuilder.add(_buildTextFrame('TRCK', trackNumber.toString()));

    // APIC (Attached Picture)
    if (coverBytes != null && coverBytes.isNotEmpty) {
      framesBuilder.add(_buildApicFrame(coverBytes));
    }

    final framesData = framesBuilder.takeBytes();
    final totalTagSize = framesData.length;

    final header = Uint8List(10);
    // 'ID3'
    header[0] = 0x49;
    header[1] = 0x44;
    header[2] = 0x33;
    // Version 2.3.0
    header[3] = 0x03;
    header[4] = 0x00;
    // Flags: 0
    header[5] = 0x00;
    // 4-byte Synchsafe integer size
    final synchsafe = _encodeSynchsafeInt(totalTagSize);
    header[6] = synchsafe[0];
    header[7] = synchsafe[1];
    header[8] = synchsafe[2];
    header[9] = synchsafe[3];

    return (BytesBuilder()
          ..add(header)
          ..add(framesData))
        .takeBytes();
  }

  Uint8List _buildTextFrame(String frameId, String text) {
    // Encoding 0x01: UTF-16 with BOM (\xFF\xFE in Little Endian)
    final bom = [0xFF, 0xFE];
    final textUnits = <int>[];
    for (final char in text.codeUnits) {
      textUnits.add(char & 0xFF);
      textUnits.add((char >> 8) & 0xFF);
    }

    final payload = (BytesBuilder()
          ..addByte(0x01) // UTF-16
          ..add(bom)
          ..add(textUnits))
        .takeBytes();

    final frame = BytesBuilder();
    frame.add(utf8.encode(frameId)); // 4 bytes Frame ID

    // 4 bytes Size (non-synchsafe in ID3v2.3)
    final size = payload.length;
    frame.add([
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ]);

    // 2 bytes Flags
    frame.add([0x00, 0x00]);

    // Payload
    frame.add(payload);

    return frame.takeBytes();
  }

  Uint8List _buildApicFrame(Uint8List imageBytes) {
    final mime = utf8.encode('image/jpeg');

    final payload = (BytesBuilder()
          ..addByte(0x00) // Encoding: ISO-8859-1 for mime and desc
          ..add(mime)
          ..addByte(0x00) // Mime terminator
          ..addByte(0x03) // Picture type: 0x03 = Front Cover
          ..addByte(0x00) // Empty description terminator
          ..add(imageBytes))
        .takeBytes();

    final frame = BytesBuilder();
    frame.add(utf8.encode('APIC'));

    final size = payload.length;
    frame.add([
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ]);

    frame.add([0x00, 0x00]); // Flags
    frame.add(payload);

    return frame.takeBytes();
  }

  List<int> _encodeSynchsafeInt(int value) {
    return [
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F,
    ];
  }

  int _decodeSynchsafeInt(int b0, int b1, int b2, int b3) {
    return ((b0 & 0x7F) << 21) |
        ((b1 & 0x7F) << 14) |
        ((b2 & 0x7F) << 7) |
        (b3 & 0x7F);
  }
}
