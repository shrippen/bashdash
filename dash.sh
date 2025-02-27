#!/bin/bash
# Verwendung dash.sh <Input File>
# benötigt shaka packager
# Input Video
INPUT="$1"

# Output Directory
OUTPUTDIRECTORY="dash"
BASENAME="${INPUT%.*}"
OUTPUT_DIR=""$BASENAME"_"$OUTPUTDIRECTORY""
mkdir -p "$OUTPUT_DIR"

# Bitraten für verschiedene Auflösungen
declare -A RESOLUTIONS
RESOLUTIONS=(
    [240]="300k"
    [360]="600k"
    [480]="1000k"
    [720]="2500k"
    [1080]="5000k"
)

# Encoder Optionen
AV1_OPTS="-c:v libsvtav1 -crf 23 -preset 8"
H264_OPTS="-c:v libx264 -crf 23 -preset: fast"
AUDIO_OPTS="-c:a libopus -ar 48k -b:a 192k -map a:0 -vbr on"

# DASH Output
DASH_OUTPUT_DIR="$OUTPUT_DIR"
mkdir -p "$DASH_OUTPUT_DIR"

# Prüfen, ob das Video eine Audiospur enthält
HAS_AUDIO=$(ffprobe -i "$INPUT" -show_streams -select_streams a -loglevel error | grep -q "codec_type=audio" && echo 1 || echo 0)

if [[ "$HAS_AUDIO" -eq 1 ]]; then
    AUDIO_INPUT="\"input=$DASH_OUTPUT_DIR/240p_h264.mp4,stream=audio,output=$DASH_OUTPUT_DIR/audio.mp4\""
else
    AUDIO_INPUT=""
fi
echo "$AUDIO_INPUT"

for RES in "${!RESOLUTIONS[@]}"; do
    BITRATE=${RESOLUTIONS[$RES]}
    HEIGHT=$(echo $RES)

    # AV1 Encoding
    ffmpeg -hwaccel auto -i "$INPUT" $AV1_OPTS -filter_complex "[0:v]scale=-2:$HEIGHT[out]" -map "[out]" -pix_fmt yuv420p -sws_flags bicubic \
        $([[ "$HAS_AUDIO" -eq 1 ]] && echo "$AUDIO_OPTS") \
        -movflags faststart -f mp4 "$DASH_OUTPUT_DIR/${HEIGHT}p_av1.mp4"

    # H264 Encoding (Fallback)
    ffmpeg -hwaccel auto -i "$INPUT" -vf "scale=-2:$HEIGHT" $H264_OPTS -map v:0 -pix_fmt yuv420p -sws_flags bicubic $([[ "$HAS_AUDIO" -eq 1 ]] && echo "$AUDIO_OPTS") \
        -movflags faststart -f mp4 "$DASH_OUTPUT_DIR/${HEIGHT}p_h264.mp4"
done

# Verpacken in DASH mit Shaka Packager
packager \
    "input=$DASH_OUTPUT_DIR/240p_av1.mp4,stream=video,output=$DASH_OUTPUT_DIR/240p_av1.mp4" \
    "input=$DASH_OUTPUT_DIR/360p_av1.mp4,stream=video,output=$DASH_OUTPUT_DIR/360p_av1.mp4" \
    "input=$DASH_OUTPUT_DIR/480p_av1.mp4,stream=video,output=$DASH_OUTPUT_DIR/480p_av1.mp4" \
    "input=$DASH_OUTPUT_DIR/720p_av1.mp4,stream=video,output=$DASH_OUTPUT_DIR/720p_av1.mp4" \
    "input=$DASH_OUTPUT_DIR/1080p_av1.mp4,stream=video,output=$DASH_OUTPUT_DIR/1080p_av1.mp4" \
    "input=$DASH_OUTPUT_DIR/240p_h264.mp4,stream=video,output=$DASH_OUTPUT_DIR/240p_h264.mp4" \
    "input=$DASH_OUTPUT_DIR/360p_h264.mp4,stream=video,output=$DASH_OUTPUT_DIR/360p_h264.mp4" \
    "input=$DASH_OUTPUT_DIR/480p_h264.mp4,stream=video,output=$DASH_OUTPUT_DIR/480p_h264.mp4" \
    "input=$DASH_OUTPUT_DIR/720p_h264.mp4,stream=video,output=$DASH_OUTPUT_DIR/720p_h264.mp4" \
    "input=$DASH_OUTPUT_DIR/1080p_h264.mp4,stream=video,output=$DASH_OUTPUT_DIR/1080p_h264.mp4" \
    $([[ "$HAS_AUDIO" -eq 1 ]] && "$AUDIO_INPUT") \
    --mpd_output "$DASH_OUTPUT_DIR/manifest.mpd"

echo "DASH-Streams wurden in $DASH_OUTPUT_DIR generiert"
