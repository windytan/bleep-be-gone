# 🤬 Bleep-be-gone

Tired of those pesky bleeps? Bleep-be-gone is here to help!

This script uses `ffmpeg` and simple zero-crossing detection to
remove the "bleep censor" sounds from a video and replaces them with silence.

Video is passed through untouched.

## Usage

`perl bleep-silencer.pl input-video.mp4`

The resulting video file is called `no_bleeps.mp4`.

There are some configurable constants inside the script; don't be afraid to modify!
For instance, the frequency range is very permissive by default. You may want to change
that to prevent false positives. Normally, censor bleeps are around 1000 Hz.

## Caveats

* It is a simple detector that gets confused by DC shift and maybe some beep-like sounds
* It abruptly cuts off the sound, there is no cross-fade
* It converts all audio to 44100 Hz stereo S16LE and re-compresses
