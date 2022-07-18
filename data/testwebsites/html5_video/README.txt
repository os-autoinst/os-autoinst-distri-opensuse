for i in {1..1000} ; do ln -s /tmp/PM5544_with_non-PAL_signals.png $(printf f-%03d.png $i) ; done
ffmpeg -framerate 10 -i f-%03d.png -pix_fmt yuv420p video.webm
ffmpeg -framerate 10 -i f-%03d.png -pix_fmt yuv420p video.mp4
