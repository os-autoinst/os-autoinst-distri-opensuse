# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ImageMagick
# Summary: Add ImageMagick test
#    This test creates, displays, and evaluates 200+ images utilizing
#    various convertion options of ImageMagick.
#
#    The examined examples were taken from:
#    https://www.imagemagick.org/Usage/canvas/ (Aug 2016)
#
#    A set of preloaded images and a script are required as input. This
#    test generates multiple new images and evaluates the output. Some
#    of the new images are converted from the preloaded images, while
#    others are drawn from scratch. The preloaded script contains all
#    the executed commands because typing them appeared to be extremely
#    time-consuming.
# Maintainer: Veronika Svecova <vsvecova@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;


sub compare {
    my ($original, $copy, $test) = @_;
    my $rmse = script_output("res=\"\$(compare -metric rmse -format \"%[distortion]\\n\" $original $copy nullim)\" || true; [[ \$? -ne 2 ]] && echo \$res || echo 2", proceed_on_failure => 1);
    die "$test failed. Expected: diff<0.1, Found: diff=$rmse" unless $rmse < 0.1;
}

sub run {
    select_console "x11";
    x11_start_program('xterm');

    become_root;
    quit_packagekit;
    zypper_call "in ImageMagick";

    # Prepare to run tests
    assert_script_run "wget --quiet " . data_url('imagemagick/im_files.tar.gz') . " -O im_files.tar.gz";
    assert_script_run "tar -xf im_files.tar.gz";
    assert_script_run "cd im_files";
    # Test image identification
    my $identify = script_output "identify test.png";
    die "Identify failed" unless index($identify, "test.png PNG 300x388 300x388+0+0 8-bit sRGB") != -1;
    # Test image comparisson algorithm
    my $comp_eval = script_output("compare -metric rmse testtilepattern.jpg testtilepattern.gif nullim 2>&1", proceed_on_failure => 1);
    ($comp_eval) = $comp_eval =~ m/(?<=\().*(?=[^(]*\))/g;
    die "ImageMagick compare doesn't work as expected" unless ($comp_eval > 0.0051 && $comp_eval < 0.0052);

    # Create image transformations to compare with pretransformed test images
    my %test_imgs = (
"Logo creation" => ["convert -fill Snow -background Green3 -strokewidth 2 -stroke Green4 -font Roboto -pointsize 256 -density 90 -size 1800x350 label:susetestlogo testlogo_t.png", "testlogo", ".png", ".png"],
        "Risize/strip quality" => ["convert test.png -filter point -resize 200% -strip -quality 90 test2_t.png", "test2", ".png", ".png"],
        Crop => ["convert test.png -gravity center -crop 100x100+0+0 +repage testcrop_t.png", "testcrop", ".png", ".png"],
"Sparse color image" => ["convert -size 400x400 xc: -colorspace RGB -sparse-color Voronoi '120,40 red 40,320 blue 270,240 lime 320,80 yellow' -scale 25% -colorspace sRGB -fill white -stroke black -draw 'circle 30,10 30,12 circle 10,80 10,82' -draw 'circle 70,60 70,62 circle 80,20 80,22' testsparse_t.png", "testsparse", ".png", ".png"],
"Sparse color blurred image" => ["convert -size 400x400 xc: -colorspace RGB -sparse-color Voronoi '120,40 red 40,320 blue 270,240 lime 320,80 yellow' -blur 0x15 -colorspace sRGB -fill white -stroke black -draw 'circle 30,10 30,12 circle 10,80 10,82' -draw 'circle 70,60 70,62 circle 80,20 80,22' testsparseblur_t.png", "testsparseblur", ".png", ".png"],
        "Tiled pattern creation" => ["convert -size 80x80 -tile-offset +20+20 pattern:checkerboard testtilepattern_t.png", "testtilepattern", ".png", ".png"],
        "png-jpg comparisson" => ["convert -size 80x80 -tile-offset +20+20 pattern:checkerboard testtilepattern_t.jpg", "testtilepattern", ".png", ".jpg"],
        "png-gif comparisson" => ["convert -size 80x80 -tile-offset +20+20 pattern:checkerboard testtilepattern_t.gif", "testtilepattern", ".png", ".gif"]
    );
    foreach my $key (keys %test_imgs) {
        assert_script_run "$test_imgs{$key}[0]";
        compare("$test_imgs{$key}[1]$test_imgs{$key}[2]", "$test_imgs{$key}[1]_t$test_imgs{$key}[3]", "$key");
        assert_script_run "rm $test_imgs{$key}[1]_t$test_imgs{$key}[3]";
    }

    # Check against needles - generated tiles image
    assert_script_run "convert -size 24x24 xc: -draw \"rectangle 3,11 20,12\" tile_line.gif";
    assert_script_run 'convert tile_line.gif -gravity center\
    \( +clone -rotate 0 -crop 24x18+0+0 -write mpr:r1 +delete \) \
    \( +clone -rotate 120 -crop 24x18+0+0 -write mpr:r2 +delete \) \
    -rotate -120 -crop 24x18+0+0 -write mpr:r3 +repage \
    -extent 72x36 -page  +0+0  mpr:r3 \
    -page +24+0  mpr:r1 -page +48+0  mpr:r2 \
    -page -12+18 mpr:r1 -page +12+18 mpr:r2 \
    -page +36+18 mpr:r3 -page +60+18 mpr:r1 \
    -flatten tile_hex_lines.jpg';
    assert_script_run "convert -size 120x120  tile:tile_hex_lines.jpg  tiled_hex_lines.jpg";
    enter_cmd "eog --fullscreen tiled_hex_lines.jpg";
    assert_screen('imagemagick-gui-test');
    send_key 'alt-f4';

    # Remove test files and finish
    assert_script_run "cd .. && rm -rf im_files im_files.tar.gz";
    enter_cmd "exit";
}

1;
