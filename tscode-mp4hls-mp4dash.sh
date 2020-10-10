#!/bin/bash

# THIS SCRIPT CONVERTS EVERY MP4 (IN THE CURRENT FOLDER AND SUBFOLDER) TO A MULTI-BITRATE VIDEO IN MP4-DASH
# For each file "videoname.mp4" it creates a folder "dash_videoname" containing a dash manifest file "stream.mpd" and subfolders containing video segments.
# Explanation: 
# https://rybakov.com/blog/

# Validation tool:
# http://dashif.org/conformance.html

# MDN reference:
# https://developer.mozilla.org/en-US/Apps/Fundamentals/Audio_and_video_delivery/Setting_up_adaptive_streaming_media_sources

# Add the following mime-types (uncommented) to .htaccess:
# AddType video/mp4 m4s
# AddType application/dash+xml mpd

# Use type="application/dash+xml" 
# in html when using mp4 as fallback:
#                <video data-dashjs-player loop="true" >
#                    <source src="/walking/walking.mpd" type="application/dash+xml">
#                    <source src="/walking/walking.mp4" type="video/mp4">
#                </video>

# DASH.js
# https://github.com/Dash-Industry-Forum/dash.js

#MYDIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
#Ondemand code: Switch to WORK_DIR as specified in paramater
MYDIR="$2"
#SAVEDIR=$(pwd)
echo "I am currently at: $PWD"

#schema definition
master_playlist="#EXTM3U
#EXT-X-VERSION:3
"

# Check programs
if [ -z "$(which ffmpeg)" ]; then
    echo "Error: ffmpeg is not installed"
    exit 1
fi

if [ -z "$(which MP4Box)" ]; then
    echo "Error: MP4Box is not installed"
    exit 1
fi

if [ -z "$(which mp4hls)" ]; then
    echo "Error: MP4hls is not installed"
    exit 1
fi

cd "$MYDIR"
echo "I am currently at: $PWD"

#TARGET_FILES=$(find ./ -maxdepth 1 -type f \( -name "*.mp4" \))
#TARGET_FILES=$(find ./ -maxdepth 1 -type f \( -name "*.mkv" -or -name "*.mp4" \))

#########################
# On demand diff code start
# get target file parameter from cmd line, instead.
TARGET_FILES="$1"
if [ $# -lt 1 ]; then
    echo "Needs a input parameter. Supply a video file name."
    exit 1
fi
fn=$(basename "$TARGET_FILES")
ext="${fn##*.}"
if [ ! -f "${fn}" ]; then
    echo "Error. File not found! - ${fn}"
    exit 1
fi
if [[ ${ext,,} == "mp4" || ${ext,,} == "mkv" || ${ext,,} == "mov" ]]; then
    echo "Format seems OK."
    echo "Working on: [$1] with extension [$ext]"
else
    echo "Supply video with compatible format. Eg. MP4, MKV, MOV."
    exit 1
fi
# On demand diff code end.
##########################

for f in $TARGET_FILES
do
  fe=$(basename "$f") # fullname of the file
  f="${fe%.*}" # name without extension

  if [ ! -d "${f}" ]; then #if directory does not exist, convert
    echo "Converting \"$f\" to multi-bitrate video in MPEG-DASH"

    mkdir "${f}"

    ffmpeg -y -i "${fe}" -c:a aac -b:a 48k -vn "${f}_audio.m4a"

    ffmpeg -y -i "${fe}" -preset veryfast -tune film -vsync passthrough -write_tmcd 0 -c:a aac -b:a 48k -c:v libx264 -x264opts 'keyint=25:min-keyint=25:no-scenecut' -maxrate 5300k -bufsize 2650k -vf 'scale=-1:1080' -pix_fmt yuv420p -f mp4 "${f}-1080p.mp4"
    ffmpeg -y -i "${fe}" -preset veryfast -tune film -vsync passthrough -write_tmcd 0 -c:a aac -b:a 48k -c:v libx264 -x264opts 'keyint=25:min-keyint=25:no-scenecut' -maxrate 2400k -bufsize 1200k -vf 'scale=-1:720' -pix_fmt yuv420p -f mp4  "${f}-720p.mp4"
    ffmpeg -y -i "${fe}" -preset veryfast -tune film -vsync passthrough -write_tmcd 0 -c:a aac -b:a 48k -c:v libx264 -x264opts 'keyint=25:min-keyint=25:no-scenecut' -maxrate 1060k -bufsize 530k -vf 'scale=-1:478' -pix_fmt yuv420p -f mp4   "${f}-480p.mp4"
    ffmpeg -y -i "${fe}" -preset veryfast -tune film -vsync passthrough -write_tmcd 0 -c:a aac -b:a 48k -c:v libx264 -x264opts 'keyint=25:min-keyint=25:no-scenecut' -maxrate 600k -bufsize 300k -vf 'scale=-1:360' -pix_fmt yuv420p -f mp4  "${f}-360p.mp4"

    # Default sample from offical manual
    #ffmpeg -i video.mp4 -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -b:v 5300k -maxrate 5300k -bufsize 2650k -vf 'scale=-1:1080' video-1080.mp4
    #ffmpeg -i video.mp4 -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -b:v 2400k -maxrate 2400k -bufsize 1200k -vf 'scale=-1:720' video-720.mp4
    #ffmpeg -i video.mp4 -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -b:v 1060k -maxrate 1060k -bufsize 530k -vf 'scale=-1:478' video-480.mp4
    #ffmpeg -i video.mp4 -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -b:v 600k -maxrate 600k -bufsize 300k -vf 'scale=-1:360' video-360.mp4
    #ffmpeg -i video.mp4 -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -b:v 260k -maxrate 260k -bufsize 130k -vf 'scale=-1:242' video-240.mp4


    #APPLY HLS
    target="${f}"
    mp4hls "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4" --verbose --segment-duration 3 --master-playlist-name=playlist.m3u8 --media-playlist-name="stream.m3u8" --output-dir="${target}/hls-media" --force

    # APPLY DASH
    mkdir "${f}/dash"
    #if audio stream does not exist, ignore it
    if [ -e "${f}_audio.m4a" ]; then
        #do not icnlude audio again, as it is already embedded in transcoded resolution source file.
        #MP4Box -dash 3000 -rap -frag-rap  -bs-switching no -profile "dashavc264:live" "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4" "${f}_audio.m4a" -out "${f}/${f}.mpd"
        MP4Box -dash 3000 -rap -frag-rap  -bs-switching no -profile "dashavc264:live" "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4" -out "${f}/dash/${f}.mpd"
        rm "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4" "${f}_audio.m4a"
    else
        MP4Box -dash 3000 -rap -frag-rap  -bs-switching no -profile "dashavc264:live" "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4" -out "${f}/dash/${f}.mpd"
        rm "${f}-1080p.mp4" "${f}-720p.mp4" "${f}-480p.mp4" "${f}-360p.mp4"
    fi




fi

done

#cd "$SAVEDIR"
