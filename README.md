# Northstar Video Player

[Download Northstar for macOS](https://thomaswales26-hash.github.io/videoplayer/) · [GitHub releases](https://github.com/thomaswales26-hash/videoplayer/releases)

A native macOS video player with a universal Apple Silicon and Intel build. It
uses AVKit/AVFoundation for playback, includes standard transport and
fullscreen controls, plays Matroska (MKV) files through FFmpeg, and detects
mounted DVD/Blu-ray data volumes so you can browse their video files.

MKV playback requires FFmpeg installed on the Mac. Install it with
`brew install ffmpeg`. Northstar first attempts a lossless remux into a
temporary MP4; if the contained codecs aren't MP4-compatible, it transcodes
video to H.264 and audio to AAC for AVKit. The temporary file is removed when
you switch videos.

## Build and run

Requires macOS 13 or later and the Apple Command Line Tools (Swift, `xcrun`,
`lipo`, and `codesign`).

```sh
./build.sh
open "build/artifacts/Northstar Video Player.app"
```

The build produces a universal app bundle and an installer package:

- `build/artifacts/Northstar Video Player.app` — contains both `arm64` and
  `x86_64` slices.
- `build/Northstar-Video-Player-macOS-universal.pkg` — installs the app in
  `/Applications`.
- `build/Northstar-Video-Player-macOS-universal.dmg` — drag-and-drop disk image
  with an Applications shortcut.

The installer is not Developer ID signed or notarized. macOS may require
confirming the install through Privacy & Security when opening a downloaded
package.

## Disc and format notes

Disc browsing works with mounted volumes containing a `VIDEO_TS` (DVD) or
`BDMV` (Blu-ray) folder. Choose a video file from the disc in the file picker.
This is file playback, not DVD/Blu-ray menu navigation. Commercial encrypted
Blu-ray playback is not supported; it requires appropriately licensed
decryption software. Playback formats and 4K/HDR performance depend on the
codecs and hardware supported by the installed version of macOS.
