# 🤬 Bleep-be-gone

Tired of those pesky bleeps? Bleep-be-gone is here to help!

This script uses `ffmpeg` and simple zero-crossing detection to
remove the "bleep censor" sounds from a video and replaces them with silence.

Video is passed through untouched.

## Usage

`perl bleep-be-gone.pl [-d] input-video.mp4`

The resulting video file is called `no_bleeps.mp4`.

`-d` enables dry run: Nothing is written out, instead you get a list of detected beeps.

There are some configurable constants inside the script; don't be afraid to modify!
For instance, the frequency range is quite permissive by default. You may want to change
it if you get false positives. Normally, censor bleeps are around 1000 Hz.

## Caveats

* It is a simple detector that gets confused by DC shift and maybe some beep-like sounds
* It abruptly cuts off the sound, there is no cross-fade
* Lossy re-compression of audio
