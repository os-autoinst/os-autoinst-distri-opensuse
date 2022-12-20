# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ImageMagick
# Summary: Add ImageMagick test
#    This test creates, displays, and evaluates 200+ images utilizing
#    various conversion options of ImageMagick.
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


sub run {
    select_console "x11";
    x11_start_program('xterm');

    become_root;
    quit_packagekit;
    zypper_call "in ImageMagick";
    enter_cmd "exit";

    assert_script_run "wget --quiet " . data_url('imagemagick/bg_script.sh') . " -O bg_script.sh";

    assert_script_run "chmod +x bg_script.sh";
    # execute the script and direct its exit code to the serial console
    enter_cmd "./bg_script.sh " . data_url('imagemagick/bg_script.sh') . "; echo bg_script-\$? > /dev/$testapi::serialdev";

    my @test_screens = qw(
      test shape plasma_fractal2 random tile_weave bg tile_aqua tile_water
      tile_rings tile_disks tree canvas_khaki canvas_salmon canvas_wheat
      color_sparse color_reset color_flatten color_extent color_border
      color_fx_constant color_semitrans color_pick_fx color_pick_sparse
      color_pick_draw color_pick_distort black_threshold white_threshold
      black_level white_level black_fx white_fx black_evaluate white_evaluate
      black_gamma white_posterize black_posterize white_alpha black_alpha
      trans_fx trans_fx_alpha_off trans_compose yellow_gamma color_matte
      grey_level trans_alpha gradient trans_evaluate gradient_range1
      trans_threshold gradient_range2 gradient_range3 gradient_ice-sea
      gradient_range4 gradient_burnished gradient_range5 gradient_grassland
      gradient_snow_scape rgradient gradient_sunset rgradient_clip
      rgradient_crop rgradient_range1 rgradient_range2 rgradient_range3
      rgradient_range4 gradient_transparent gradient_sigmoidal
      gradient_trans_colorize gradient_cosine gradient_peak gradient_bands
      gradient_diagonal gradient_srt gradient_swirl gradient_trapezoid
      gradient_arc gradient_circle gradient_angle_even gradient_angle_masked
      gradient_angle_odd gradient_triangle gradient_bird gradient_venetian
      gradient_vent_diag gradient_colormap gradient_rainbow gradient_hue_polar
      gradient_rainbow_2 gradient_resize gradient_resize2 gradient_resize3
      gradient_resize4 gradient_resize5 gradient_rs_rainbow
      gradient_interpolated gradient_clut gradient_clut_recolored
      gradient_bilinear gradient_mesh gradient_catrom gradient_fx_linear
      gradient_fx_x4 gradient_fx_cos gradient_fx_radial gradient_fx_spherical
      gradient_fx_quad2 gradient_fx_angular gradient_inverse_alt
      gradient_shepards_alt gradient_inverse_RGB gradient_inverse_RGB_Hue
      sparse_bary_triangle sparse_barycentric sparse_bary_triangle_2
      sparse_bary_0 sparse_bary_gradient sparse_bary_gradient_2
      diagonal_gradient sparse_bary_two_point diagonal_gradient_2
      sparse_bilinear sparse_bilin_0 sparse_voronoi gradient_scale
      sparse_voronoi_ssampled gradient_math sparse_voronoi_smoothed
      gradient_equiv sparse_voronoi_blur gradient_shifted
      sparse_voronoi_gradient gradient_chopped sparse_shepards sparse_inverse
      sparse_shepards_0.5 sparse_shepards_1 sparse_shepards_2 plasma_smooth
      sparse_shepards_3 sparse_shepards_8 sparse_shepards_gray
      rose_alpha_gradient sparse_source sparse_fill shape_edge_pixels
      shape_edge_in_lights shape_in_lights sparse_blur_simple
      sparse_blur_pyramid sparse_lines_near_source sparse_lines_near
      plasma_paint plasma_emboss plasma_sharp plasma_seeded plasma_rnd1
      plasma_rnd2 plasma_rnd3 plasma_rnd4 plasma_rnd5 random_mask random_black
      random_white random_1 random_trans random_3 random_5 random_10 random_20
      random_0_gray random_1_gray random_3_gray random_5_gray random_10_gray
      random_20_gray random_0_thres random_1_thres random_3_thres random_5_thres
      random_10_thres random_20_thres random_5_blobs ripples_1 ripples_2
      ripples_3 ripples_4 random_enhanced ripples_4e random_sigmoidal ripples_4s
      ripples_3e000 ripples_3e090 ripples_3e180 ripples_3e270 ripples_3.5e
      tile_size tile_over tile_draw tile_reset tile_distort_sized offset_tile
      offset_pattern offset_tile_fill offset_pattern_fail offset_pattern_good
      tile_clone tile_clone_flip tile_mpr tile_mpr_reset tile_mpr_fill
      tile_distort tile_distort_checks tile_distort_polar pattern_default
      pattern_hexagons pattern_colored pattern_color_checks
      pattern_color_hexagons pattern_distorted tile_mod_failure tile_mod_vpixels
      tile_slanted_bricks tile_mod_success tile_circles tile_hexagons
      tiled_hexagons tile_line tile_hex_lines tiled_hex_lines
    );
    for my $screen (@test_screens) {
        assert_screen "imagemagick_$screen";
        send_key 'alt-f4';
    }

    # waiting for the exit code of the script
    wait_serial "bg_script-0";
    # clean-up
    assert_script_run "rm bg_script.sh";
    enter_cmd "exit";
}

1;
