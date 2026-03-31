# AllFormat Media Converter (Flutter)

Production-ready Android media converter using **FFmpegKit**.

## Features
- **Audio**: MP3 ↔ WAV ↔ AAC ↔ FLAC ↔ OGG
- **Video**: MP4 ↔ MOV ↔ MKV ↔ AVI ↔ WEBM
- **Image**: JPG ↔ PNG ↔ WEBP ↔ BMP
- Saves outputs to **`/storage/emulated/0/AllFormatConverter/`** when available (fallbacks to app documents dir if not).

## Dependencies
- `ffmpeg_kit_flutter` (FFmpeg/FFprobe)
- `file_picker`
- `permission_handler`
- `path_provider`

## Output folder
The app attempts to save converted files into:
- **`/AllFormatConverter/`** (i.e. `/storage/emulated/0/AllFormatConverter/`)

## Android permissions
Configured in `android/app/src/main/AndroidManifest.xml`:
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (Android 13+)
- `READ_EXTERNAL_STORAGE` (<= Android 12)
- `MANAGE_EXTERNAL_STORAGE` (Android 11+, for writing to `/AllFormatConverter/`)

## Example FFmpeg command mappings
These are implemented in `lib/services/media_conversion_service.dart`.

### Audio
- **To MP3**: `-y -i "in" -vn -ar 44100 -ac 2 -b:a 192k "out.mp3"`
- **To WAV**: `-y -i "in" -vn -acodec pcm_s16le -ar 44100 -ac 2 "out.wav"`
- **To AAC**: `-y -i "in" -vn -c:a aac -b:a 192k "out.aac"`
- **To FLAC**: `-y -i "in" -vn -c:a flac "out.flac"`
- **To OGG**: `-y -i "in" -vn -c:a libvorbis -qscale:a 5 "out.ogg"`

### Video
- **To MP4 (MPEG-4/AAC)**: `-y -i "in" -c:v mpeg4 -q:v 5 -c:a aac -b:a 128k "out.mp4"`
- **To MOV (MPEG-4/AAC)**: `-y -i "in" -c:v mpeg4 -q:v 5 -c:a aac -b:a 128k "out.mov"`
- **To MKV (MPEG-4/AAC)**: `-y -i "in" -c:v mpeg4 -q:v 5 -c:a aac -b:a 128k "out.mkv"`
- **To AVI (MPEG-4/MP3)**: `-y -i "in" -c:v mpeg4 -q:v 5 -c:a mp3 -qscale:a 4 "out.avi"`
- **To WEBM (VP8/Vorbis)**: `-y -i "in" -c:v libvpx -b:v 1M -c:a libvorbis "out.webm"`

### Image
- **To JPG**: `-y -i "in" -q:v 2 "out.jpg"`
- **To PNG**: `-y -i "in" -compression_level 2 "out.png"`
- **To WEBP**: `-y -i "in" -q:v 50 "out.webp"`
- **To BMP**: `-y -i "in" "out.bmp"`

