#!/usr/bin/perl
#         ______ __
#  ______|   __ \  |.-----.-----.-----.______
# |______|   __ <  ||  -__|  -__|  _  |______|
#        |______/__||_____|_____|   __|
#  ______         _______       |__|  windytan 2023
# |   __ \.-----.|     __|.-----.-----.-----.-----.
# |   __ <|  -__||    |  ||  _  |  _  |     |  -__|
# |______/|_____||_______||___  |_____|__|__|_____|
#                         |_____|

use warnings;
use strict;

use constant {
  # Audio sample rate
  FS             => 44100,

  # Detection limits for the beep frequency (Hz)
  FMIN           => 400,
  FMAX           => 1600,

  # Minimum duration to detect a beep (sec)
  MIN_DURATION_S => 0.500,

  OUTPUT_FILE    => "no_bleeps.mp4"
};

use constant {
  BUFFER_LEN   => MIN_DURATION_S * 1.1 * FS,
  MAX_DISTANCE => FS / FMIN / 2,
  MIN_DISTANCE => FS / FMAX / 2,
};


my $is_dry_run = 0;
if (($ARGV[0] // "") eq "-d") {
  $is_dry_run = 1;
  shift @ARGV;
}

die "Usage: perl bleep-be-gone.pl [-d] input-video.mp4" if (@ARGV != 1);

# We use these circular buffers to enable look-ahead function
my @detection_buffer = (0) x BUFFER_LEN;
my @output_buffer_l  = (0) x BUFFER_LEN;
my @output_buffer_r  = (0) x BUFFER_LEN;

# This noise offsets 'too clean' sine waves from zero.
# (Though we could also use different logic to detect a zero-crossing.)
# It also effectively sets a minimum allowed volume.
my @noise_buffer     = map { (rand() - .5) * 1e-4 } 1..BUFFER_LEN;

# Open input and output stream to ffmpeg.
my $audio_format = "-f s16le -acodec pcm_s16le -ar ".FS." -ac 2";
(my $in_video_file = $ARGV[0]) =~ s/(["])/\\$1/g;
open my $in, "-|",  "ffmpeg -hide_banner -loglevel error -i \"$in_video_file\" $audio_format -"
                    or die ($!);
my $out;

if (not $is_dry_run) {
  open $out,  "|-", "ffmpeg -y -i \"$in_video_file\" $audio_format -i - ".
                    "-c:v copy -map 0:v:0 -map 1:a:0 ".OUTPUT_FILE
                    or die ($!);
}

my $nsample                 = 0;
my $output_store_ptr        = 0;
my $is_detected_long_enough = 0;
my $detection_length_so_far = 0;
my $was_previously_detected_long_enough = 0;
my $is_potentially_detected = 0;
my $nsamples_since_last_zc  = 0;
my $prev_sample             = 0;

# Loop through audio stream
while (not eof $in) {
  read $in, my $lsample, 2;
  read $in, my $rsample, 2;

  $lsample = unpack "s", $lsample;
  $rsample = unpack "s", $rsample;

  $output_buffer_l[$output_store_ptr] = $lsample;
  $output_buffer_r[$output_store_ptr] = $rsample;

  my $sample = ($lsample + $rsample) + $noise_buffer[$output_store_ptr];

  $nsamples_since_last_zc++;

  # Detect zero-crossing
  if ($sample * $prev_sample < 0) {
    $is_potentially_detected = ($nsamples_since_last_zc >= MIN_DISTANCE &&
                                $nsamples_since_last_zc <= MAX_DISTANCE);
    $nsamples_since_last_zc = 0;
  }
  $prev_sample = $sample;

  # Wait for long enough beep
  if ($is_potentially_detected) {
    $detection_length_so_far++;
    $is_detected_long_enough =
      ($detection_length_so_far >= MIN_DURATION_S * FS);
  } else {
    $detection_length_so_far = 0;
    $is_detected_long_enough = 0;
  }

  # True rising edge of beep
  if ($is_detected_long_enough and not $was_previously_detected_long_enough) {
    # extend detection backwards
    for (my $i = $output_store_ptr; $i > $output_store_ptr - MIN_DURATION_S * FS; $i--) {
      $detection_buffer[$i] = 1;
    }

    if ($is_dry_run) {
      printf "Bleep @ %.1f s\n", $nsample / FS - MIN_DURATION_S;
    }
  }
  $detection_buffer[$output_store_ptr] = $is_detected_long_enough;
  $was_previously_detected_long_enough = $is_detected_long_enough;

  my $output_write_ptr = ($output_store_ptr + 1) % BUFFER_LEN;

  # Skip empty buffer in the beginning...
  if (!$is_dry_run && $nsample >= BUFFER_LEN) {

    # Output (possibly muted) audio
    print $out pack "s", $output_buffer_l[$output_write_ptr] *
                         (1 - $detection_buffer[$output_write_ptr]);
    print $out pack "s", $output_buffer_r[$output_write_ptr] *
                         (1 - $detection_buffer[$output_write_ptr]);
  }

  $output_store_ptr = $output_write_ptr;
  $nsample++;
}
close $in;
close $out if (not $is_dry_run);
