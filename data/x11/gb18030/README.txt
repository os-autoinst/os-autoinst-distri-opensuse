This is documentation for files under "data/x11/gb18030/". These files are
needed for "tests/x11/gb18030.pm".

## gb18030-test-data-original.zip

This file contains all the original test files needed for GB18030 certification.
We only use 2 of them, "double.txt" and "four.txt", and they are preprocessed
described as bellow.

## preprocess double.txt and four.txt

"double.txt" and "four.txt" are preprocessed by emacs, in order to have as many
characters per line possible and avoid line break.

    emacs -Q --eval "(set-coding-system-priority 'utf-8 'gb18030)" double.txt
    # C-x f 90  ## set-fill-column to 90
    # C-x h     ## select whole buffer
    # M-q       ## use function "fill-column" to rearrange paragraphs

## generate needles automatically

Download testing qcow2 image from openqa website, boot it up and configure gedit
and system fonts using commands described in "tests/x11/gb18030.pm".

Install package "xdotool" and "ImageMagick".

Copy "double.txt", "four.txt" and "gb18030-json.template" into the VM, and run
following script:

````
#! /bin/sh

gedit double.txt &

## move cursor to beginning and use F11 to fullscreen
sleep 15

for i in {1..45}; do
    import -window root -pause 1 gb18030-double-page-$i-`date +%Y%m%d`.png;
    sed "s/gb18030-double-page-1/gb18030-double-page-$i/" gb18030-json.template > gb18030-double-page-$i-`date +%Y%m%d`.json
    xdotool key Page_Down;
    sleep 1;
    xdotool key Up;
    sleep 1;
done
````
