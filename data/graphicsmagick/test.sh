#!/bin/bash

# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: GraphicMagick testsuite
# Maintainer: Ivan Lausuch <ilausuch@suse.com>
#
# Usage; test.sh path_of_resources

#####################
# Download resorces
#####################

resources=(
  black.png
  blue.png
  check_compare.pl
  check_compare_PSNR.pl
  check_size.pl
  degradation_1bit.png
  degradation_grayscale.png
  degradation_monochrome.png
  degradation.png
  logo-primary.png
  magenta.png
  montage1.png
  montage2.png
  noise_blur_10.png
  noise_emboss_10.png
  noise_with_tile_logo.png
  noise.gif
  quadrants500x500_transparent_blue.png
  quadrants500x500.png
  quadrants500x500.xcf
  red_circle.png
  red.png
  script.html
  suse_tail_composite.png
  suse_tail_contrast_40.png
  suse_tail_contrast_90.png
  suse_tail_gamma_0.png
  suse_tail_sharpen5.png
  suse_tail.jpg
  test_animation.gif
  test_text_variables.png
  test_text.png
  test_texture.png
  test_virtual_pixel_constant.png
  test_virtual_pixel_edge.png
  test_virtual_pixel_tile.png
  test_virtual_pixel_mirror.png
  white.png
)

for item in ${resources[*]}
do
  wget --quiet "$1/$item" -O $item
done

##########################
# Prepare some resources
#########################

gm convert degradation.png degradation.jpg
gm convert noise.gif noise.jpg
gm convert noise.gif -resize 500x500 noise500x500.png
gm convert black.png -resize 10x10 black10x10.png
gm convert -crop 500x250+0+0! quadrants500x500.png quadrants_up_500x250.png

gm convert red.png frame1.gif
gm convert black.png frame2.gif
gm convert blue.png frame3.gif
gm convert white.png frame4.gif

##########################
# Helpers
##########################

function compare {
  metric=$1
  image1=$2
  image2=$3
  tolerance=$4
  inversion=$5
  channel=$6

  if [ "$metric" = "PSNR" ]; then
    script="check_compare_PSNR.pl"
  else
    script="check_compare.pl"
  fi

  if [ -z "$channel" ]; then
    channel="Total"
  fi

  if [ ! -f $image1 ]; then
    echo "KO"
    return
  fi

  if [ ! -f $image2 ]; then
    echo "KO"
    return
  fi

  gm compare -metric $metric $image1 $image2 | grep $channel | perl $script $tolerance $inversion
}

function montage_compare {
  metric=$1
  image1=$2
  image2=$3
  tolerance=$4

  if [[ $(uname -m) =~ i.86 ]]; then
    # i586, i686
    tolerance=0.4
  fi
  compare $metric $image1 $image2 $tolerance
}

function convert_and_compare {
  image1=$1
  image2=$2
  tolerance=$3
  options=$4
  image3=$5

  if [ "$options" = '-' ]; then
    options=""
  fi

  if [ -z "$image3" ]; then
    image3=$image2
  fi

  options="${options//_/ }"
  options="${options//^/%}"

  gm convert $options $image1 $image2 && compare "MAE" $image3 $image2 $tolerance
}

function resize_and_check {
  image1=$1
  image2=$2
  resize=$3
  w=$4
  h=$5

  if [ "$resize" = '-' ]; then
    resize=${w}x${h}!
  fi

  gm convert -resize $resize $image1 $image2 && perl check_size.pl $image2 $w $h
}

function resize_no_crash {
  image1=$1
  image2=$2
  resize=$3

  gm convert -resize $resize $image1 $image2 2>/dev/null || echo -n "OK"
}

function crop_and_check {
  image1=$1
  image2=$2
  image3=$3
  w=$4
  h=$5
  x=$6
  y=$7
  options=$8

  gm convert $options -crop ${w}x${h}+${x}+${y} $image1 $image2 && perl check_size.pl $image2 $w $h >/dev/null && \
  compare PAE $image2 $image3 0
}

###############################
# Tests
###############################

tests=(
  # Test 1. Compararions

  # a. Compare two equal images (PNG vs PNG)
  "compare MAE noise.gif noise.gif 0"
  "compare MSE noise.gif noise.gif 0"
  "compare PAE noise.gif noise.gif 0"
  "compare PSNR noise.gif noise.gif inf"
  "compare RMSE noise.gif noise.gif 0"

  # b. Compare two equivalent images (PNG vs JPEG) where the error is under a low tolerance.
  # JPEG compression introduces an error but it has to be very close to 0 in case of low frequency images like a degradation
  "compare MAE degradation.png degradation.jpg 0.01"
  "compare MSE degradation.png degradation.jpg 0.01"
  "compare PAE degradation.png degradation.jpg 0.03"
  "compare PSNR degradation.png degradation.jpg 40"
  "compare RMSE degradation.png degradation.jpg 0.01"

  # JPEG compression introduces an error in high frequency images like noise
  # MAE, PAE and RMSE are more sensible to this high frequency error
  "compare MAE noise.gif noise.jpg 0.03"
  "compare MSE noise.gif noise.jpg 0.01"
  "compare PAE noise.gif noise.jpg 0.2"
  "compare PSNR noise.gif noise.jpg 20"
  "compare RMSE noise.gif noise.jpg 0.04"

  # c. Compare two different images
  # MAE and RMSE are more sensible than MSE
  # PAE is highly sensible, in this case both images are completelly different
  "compare MAE degradation.png noise500x500.png 0.4 1"
  "compare MSE degradation.png noise500x500.png 0.2 1"
  "compare PAE degradation.png noise500x500.png 0.99 1"
  "compare PSNR degradation.png noise500x500.png 6"
  "compare RMSE degradation.png noise500x500.png 0.4 1"

  # d. Compare two different images with different sizes (Expected not crash)
  # In version 1.3.28 2018-01-20 Q16 this crash
  # In version (tumbleweed) 1.3.33 2019-07-20 Q16 this works
  "compare MAE noise500x500.png noise.gif 0 1"
  "compare MSE degradation.png noise500x500.png 0 1"
  "compare PAE degradation.png noise500x500.png 0 1"
  "compare PSNR degradation.png noise500x500.png 0"
  "compare RMSE degradation.png noise500x500.png 0 1"]


  # Test 2. Conversion

  "convert_and_compare degradation.png __1.tiff 0"
  "convert_and_compare degradation.png __1.bmp 0"
  "convert_and_compare degradation.png __1.ppm 0"
  "convert_and_compare degradation.png __1.pnm 0"
  "convert_and_compare degradation.png __1.pdf 0"
  "convert_and_compare degradation.png __1.jp2 0"

  # Note: JPG loses some information during the compression because the fourier transformation
  "convert_and_compare degradation.png __1.jpg 0.01"

  # Note: WebP can be lossy compression, this is the case
  "convert_and_compare degradation.png __1.webp 0.01"

  # Note: GIF loses information during the compression because it only allows palete color table with 256 colors
  "convert_and_compare degradation.png __1.gif 0.01"

  # PGM only allows grayscale images
  "convert_and_compare degradation.png __1.pgm 0.01 - degradation_grayscale.png"

  # PBM are binary images
  "convert_and_compare degradation.png __1.pbm 0.01 - degradation_1bit.png"


  # Test 3. Resize, rotate, crop, flip

  # a. Resize (duplicate, divide and reduce to 1 pixel)
  "resize_and_check noise.gif __1.png - 512 256"
  "resize_and_check noise.gif __1.png - 128 256"
  "resize_and_check noise.gif __1.png - 256 512"
  "resize_and_check noise.gif __1.png - 256 128"
  "resize_and_check noise.gif __1.png - 512 512"
  "resize_and_check noise.gif __1.png - 512 512"
  "resize_and_check noise.gif __1.png - 128 128"
  "resize_and_check noise.gif __1.png - 1 256"
  "resize_and_check noise.gif __1.png - 256 1"
  "resize_and_check noise.gif __1.png - 1 1"

  # b. Duplicate the width and height maintaining the aspect ratio
  "resize_and_check noise.gif __1.png 512x! 512 512"
  "resize_and_check noise.gif __1.png x512! 512 512"

  # c. Divide by two the width and height maintaining the aspect ratio
  "resize_and_check noise.gif __1.png 128x! 128 128"
  "resize_and_check noise.gif __1.png x128! 128 128"

  # d. Reduce one of the sizes to 0 expecting an error but not a crash
  "resize_no_crash noise.gif __1.png 0x256!"
  "resize_no_crash noise.gif __1.png 256x0!"
  "resize_no_crash noise.gif __1.png 0x0!"
  "resize_no_crash noise.gif __1.png 0x!"
  "resize_no_crash noise.gif __1.png x0!"

  # e .crop image
  "crop_and_check quadrants500x500.png __1.png blue.png 250 250 0 0"
  "crop_and_check quadrants500x500.png __1.png red.png 250 250 250 0"
  "crop_and_check quadrants500x500.png __1.png black.png 250 250 0 250"
  "crop_and_check quadrants500x500.png __1.png white.png 250 250 250 250"

  # f. Flip H
  "crop_and_check quadrants500x500.png __1.png red.png 250 250 0 0 -flop"

  # g. Flip V
  "crop_and_check quadrants500x500.png __1.png black.png 250 250 0 0 -flip"


  # Test 4. Special effects and modifications

  # a. Sharp the image and compare with an previously prepossessed image
  "convert_and_compare suse_tail.jpg __1.png 0.01 -sharpen_5 suse_tail_sharpen5.png"

  # b. Convert to monochrome and compare with an previously prepossessed image
  "convert_and_compare degradation.png __1.png 0.01 -monochrome degradation_monochrome.png"

  # c. Decorate an image with a border or frame
  "gm convert degradation.png -bordercolor black -border 10 __1.png;gm convert -crop 10x10+0+0 __1.png __2.png;compare PAE __2.png black10x10.png"

  # d. Create an image with a solid color background
  "gm convert -size 250x250 -type TrueColor xc:red __1.png;compare PAE __1.png red.png"

  # e. Flatten an image
  "convert_and_compare quadrants500x500.xcf __1.png 0.01 -flatten quadrants500x500.png"

  # f. Composite image on background color canvas image
  "convert_and_compare suse_tail.jpg __1.png 0 -thumbnail_120x80_-background_red_-gravity_center_-extent_140x100-10-5 suse_tail_composite.png"

  # g. Threshold
  # Note: ^ replaces % (this is an special case)
  "convert_and_compare degradation.png __1.png 0 -threshold_50^ degradation_1bit.png"

  # h. Adjust the level of image contrast (black, white and gray levels)
  "convert_and_compare suse_tail.jpg __1.png 0.01 -level_90^,90^ suse_tail_contrast_90.png"
  "convert_and_compare suse_tail.jpg __1.png 0.01 -level_40^,40^ suse_tail_contrast_40.png"

  # i. Level of gamma correction
  "convert_and_compare suse_tail.jpg __1.png 0.01 -gamma_0 suse_tail_gamma_0.png"

  # j. Extract one channel
  "gm convert -channel red red.png __1.png; compare PAE red.png __1.png 0 0 Red"
  "gm convert -channel red red.png __1.png; compare PAE blue.png __1.png 0 1 Red"
  "gm convert -channel blue blue.png __1.png; compare PAE blue.png __1.png 0 0 Blue"
  "gm convert -channel blue blue.png __1.png; compare PAE red.png __1.png 0 1 Blue"

  # k. Blur
  "convert_and_compare noise.gif __1.png 0.01 -blur_10 noise_blur_10.png"
  "convert_and_compare noise.gif __1.png 0.01 -emboss_10 noise_emboss_10.png"

  # l. Virtual pixels
  "gm convert degradation.png -virtual-pixel Constant -background red -wave 10 __1.png;compare MAE __1.png test_virtual_pixel_constant.png 0.01"
  "gm convert degradation.png -virtual-pixel Edge -wave 40 __1.png;compare MAE __1.png test_virtual_pixel_edge.png 0.01"
  "gm convert degradation.png -virtual-pixel Tile -wave 40 __1.png;compare MAE __1.png test_virtual_pixel_tile.png 0.01"
  "gm convert degradation.png -virtual-pixel Mirror -wave 40 __1.png;compare MAE __1.png test_virtual_pixel_mirror.png 0.01"


  # Test 5. Transparencies

  # a. Create a transparent image removing the background color and compare with a previously processed image
  "convert_and_compare quadrants500x500.png __1.png 0 -transparent_blue quadrants500x500_transparent_blue.png"

  # b. Convert a PNG with transparent background to a JPEG with a color using a color name
  "convert_and_compare quadrants500x500_transparent_blue.png __1.jpg 0.01 -background_blue quadrants500x500.png"

  # c. Convert a PNG with transparent background to a JPEG with a color using a color code
  "convert_and_compare quadrants500x500_transparent_blue.png __1.jpg 0.01 -background_#0000ff quadrants500x500.png"

  # d. Convert a PNG with transparent background to a JPEG with a color using a rbg three components
  "convert_and_compare quadrants500x500_transparent_blue.png __1.jpg 0.01 -background_rgb(0,0,65535) quadrants500x500.png"


  # Test 6. Create a montage of image thumbnails
  # http://www.graphicsmagick.org/montage.html

  # a. Create a montage using a set of images and compare with a previously preprocesed image
  "gm montage degradation.png logo-primary.png __1.png;montage_compare PAE __1.png montage1.png 0"

  # b. Create a montage using a textured background
  "gm montage -texture noise.gif degradation.png logo-primary.png __1.png;montage_compare PAE __1.png montage2.png 0"


  # Test 7. GIF animations

  # a. Using a set of images convert them in a sequence for a animated GIF
  "gm convert frame*.gif __1.gif;echo OK"

  # b. Extract gif images
  "gm convert test_animation.gif[0] __1.gif;compare MAE __1.gif frame1.gif 0.01"
  "gm convert test_animation.gif[1] __1.gif;compare MAE __1.gif frame2.gif 0.01"
  "gm convert test_animation.gif[2] __1.gif;compare MAE __1.gif frame3.gif 0.01"
  "gm convert test_animation.gif[3] __1.gif;compare MAE __1.gif frame4.gif 0.01"


  # Test 8. Composite images

  # a. Composite an image from two images
  "gm composite blue.png quadrants500x500_transparent_blue.png __1.png;compare PAE __1.png quadrants500x500.png 0"

  # b. Compute the difference between images:
  "gm composite -compose difference red.png blue.png __1.png;compare PAE __1.png magenta.png 0"

  # c. Composite an image from two images in a specific position
  "gm composite -geometry 250x250+250+0 red.png  blue.png -resize 500x250! __1.png; compare PAE __1.png quadrants_up_500x250.png 0"

  # d. Tile a logo across your image:
  "gm composite -tile logo-primary.png noise.gif __1.png; compare PAE __1.png noise_with_tile_logo.png 0"


  # Test 9. Draw shapes and text on a image

  # a. Draw a rectangle in a image
  "special 0 __1.png"

  #b. Draw a circle in a image
  "special 1 __1.png"

  # c. Draw text in a image
  "special 2 __1.png"

  # d. Draw text with variables
  "special 3 __1.png"

  # e. Draw using a texture
  "special 4"


  # Test 10. Big images

  # a. Scale a image to big image
  "resize_and_check degradation.png __1.png - 5000 1000"

  # b. Downgrade a huge image
  "resize_and_check _-_1.png __1.png - 500 500"


  # Test 11.  Batch operations
  # a. batch http://www.graphicsmagick.org/batch.html
  "special 5"

  # Test 12. Mogrify
  # b. bundle operations http://www.graphicsmagick.org/mogrify.html
  "special 6"

  # Test 13. Test scripting
  # http://www.graphicsmagick.org/conjure.html
  "gm conjure -dimensions 10x10 script.html; perl check_size.pl script_test.png 10 10"

)

function special(){
  case $1 in
    0) gm convert -resize 500x250! -fill red -draw 'rectangle 250,0 500,250' blue.png $2 && compare PAE $2 quadrants_up_500x250.png 0;;
    1) gm convert -fill red -draw 'circle 125,125 125,0' white.png $2 && compare PAE $2 red_circle.png 0;;
    2) gm convert -fill red -draw 'text 0,20 "TEST"' black.png $2 && compare MAE $2 test_text.png 0.01;;
    3) gm convert -draw 'text 100,100 "%f %wx%h"' white.png $2 && compare MAE $2 test_text_variables.png 0.01;;
    4) gm convert -size 500x500 xc:red -tile noise.gif -draw 'rectangle 10,10 100,50' __1.png && compare PAE __1.png test_texture.png 0;;
    5) for file in frame*.png; do
        outfile=`basename $file .png`.jpg
        echo convert "'$file'" -rotate 90 \
        +profile "'*'" "'$outfile'"
      done | gm batch - && echo -n "OK"
      ;;
    6) gm mogrify -format tiff frame*.gif && [ -f "frame1.tiff" ] && \
       [ -f "frame2.tiff" ] && [ -f "frame3.tiff" ] && [ -f "frame4.tiff" ] &&\
       echo "OK"
      ;;
  esac
}

######################################
# Main program
######################################

count_ok=0
ok_list=()
count_ko=0
ko_list=()

for index in ${!tests[*]}
do
    command=${tests[$index]}
    command="${command//_-_/.\/$((index-1))-}"
    command="${command//__/.\/$index-}"
    original_command=$command
    command=$(echo $command | perl -pe "s/( )/%/g")
    command=$(echo $command | perl -pe "s/(;)/ /g")

    for cmd in $command; do
      cmd=$(echo $cmd | perl -pe "s/(%)/ /g")

      res=$($cmd)
      if [ $? -ne 0 ]; then
        res="KO"
        break;
      fi
    done

    if [ "$res" = "OK" ];then
      ok_list[$count_ok]=$index
      count_ok=$(( count_ok + 1 ))
    else
      ko_list[$count_ko]=$index
      count_ko=$(( count_ko + 1 ))
    fi

    echo "$index - $res - $original_command"
done

echo "OK: $count_ok , ERRORS: $count_ko"

exit $count_ko
