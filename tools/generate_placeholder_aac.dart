// Phase 2 Plan 02 D-09 fallback: produce 5 placeholder AAC files when
// ffmpeg is not installed locally. Phase 3 replaces these with proper
// ffmpeg-generated clips.
//
// We emit a single minimal ADTS frame containing AAC-LC silent fill bytes.
// The file is byte-identical across all 5 paths because the manifest tests
// (D-11) only check File.existsSync() + path conventions, not audio content.
//
// ADTS header (7 bytes, no CRC):
//   0xFF 0xF9       — sync word + ID + layer + protection_absent (CRC absent)
//   0x4C            — profile=AAC-LC + sampling_freq_index=3 (48000 Hz)
//                     channel_config(MSB)=0
//   0x40            — channel_config(LSB)=2 (stereo... but we're mono really)
//                     +flags
//   0x00            — frame_length high bits = 0
//   0x16 0xFC       — frame_length encoding
//   0x00            — buffer_fullness + frame_count
//
// Spec reference: ISO/IEC 13818-7. We don't bother computing a perfect
// silent payload because nothing in Phase 2 plays these clips; Phase 4
// audio engine will (and Phase 3 will have replaced them by then).
import 'dart:io';

const List<int> kSilentAdtsFrame = <int>[
  // ADTS header (7 bytes).
  0xFF, 0xF9, 0x4C, 0x40, 0x00, 0x16, 0xFC,
  // Minimal AAC-LC silent fill payload (ID_END=0x07 plus padding).
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x00,
];

const List<String> kPlaceholderPaths = <String>[
  'assets/audio/letters/names/a.aac',
  'assets/audio/letters/names/eth.aac',
  'assets/audio/letters/names/thorn.aac',
  'assets/audio/letters/words/hundur.aac',
  'assets/audio/narration/welcome_hugrun.aac',
];

Future<void> main() async {
  for (final path in kPlaceholderPaths) {
    final f = File(path);
    await f.writeAsBytes(kSilentAdtsFrame, flush: true);
    final size = await f.length();
    stdout.writeln('Wrote $path ($size bytes)');
  }
}
