# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console "x11";

    x11_start_program "xterm";

    become_root;
    pkcon_quit;
    zypper_call "in ImageMagick";
    type_string "exit\n";

    assert_script_run "wget --quiet " . data_url('imagemagick/bg_script.sh') . " -O bg_script.sh";
    type_string "chmod +x bg_script.sh; ./bg_script.sh " . data_url('imagemagick/bg_script.sh') . " \n";

    assert_screen "imagemagick_test";
    send_key "alt-f4";

    assert_screen "imagemagick_shape";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_fractal2";
    send_key "alt-f4";

    assert_screen "imagemagick_random";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_weave";
    send_key "alt-f4";

    assert_screen "imagemagick_bg";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_aqua";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_water";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_rings";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_disks";
    send_key "alt-f4";

    assert_screen "imagemagick_tree";
    send_key "alt-f4";

    assert_screen "imagemagick_canvas_khaki";
    send_key "alt-f4";

    assert_screen "imagemagick_canvas_salmon";
    send_key "alt-f4";

    assert_screen "imagemagick_canvas_tomato";
    send_key "alt-f4";

    assert_screen "imagemagick_canvas_rose_red";
    send_key "alt-f4";

    assert_screen "imagemagick_canvas_wheat";
    send_key "alt-f4";

    assert_screen "imagemagick_color_levelc";
    send_key "alt-f4";

    assert_screen "imagemagick_color_colorize";
    send_key "alt-f4";

    assert_screen "imagemagick_color_sparse";
    send_key "alt-f4";

    assert_screen "imagemagick_color_reset";
    send_key "alt-f4";

    assert_screen "imagemagick_color_flatten";
    send_key "alt-f4";

    assert_screen "imagemagick_color_extent";
    send_key "alt-f4";

    assert_screen "imagemagick_color_border";
    send_key "alt-f4";

    assert_screen "imagemagick_color_fx_constant";
    send_key "alt-f4";

    assert_screen "imagemagick_color_fx_math";
    send_key "alt-f4";

    assert_screen "imagemagick_color_semitrans";
    send_key "alt-f4";

    assert_screen "imagemagick_color_pick_fx";
    send_key "alt-f4";

    assert_screen "imagemagick_color_pick_sparse";
    send_key "alt-f4";

    assert_screen "imagemagick_color_pick_draw";
    send_key "alt-f4";

    assert_screen "imagemagick_color_pick_distort";
    send_key "alt-f4";

    assert_screen "imagemagick_black_threshold";
    send_key "alt-f4";

    assert_screen "imagemagick_white_threshold";
    send_key "alt-f4";

    assert_screen "imagemagick_black_level";
    send_key "alt-f4";

    assert_screen "imagemagick_white_level";
    send_key "alt-f4";

    assert_screen "imagemagick_black_fx";
    send_key "alt-f4";

    assert_screen "imagemagick_white_fx";
    send_key "alt-f4";

    assert_screen "imagemagick_black_evaluate";
    send_key "alt-f4";

    assert_screen "imagemagick_white_evaluate";
    send_key "alt-f4";

    assert_screen "imagemagick_black_gamma";
    send_key "alt-f4";

    assert_screen "imagemagick_white_posterize";
    send_key "alt-f4";

    assert_screen "imagemagick_black_posterize";
    send_key "alt-f4";

    assert_screen "imagemagick_white_alpha";
    send_key "alt-f4";

    assert_screen "imagemagick_black_alpha";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_fx";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_fx_alpha_off";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_compose";
    send_key "alt-f4";

    assert_screen "imagemagick_yellow_gamma";
    send_key "alt-f4";

    assert_screen "imagemagick_color_matte";
    send_key "alt-f4";

    assert_screen "imagemagick_grey_level";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_alpha";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_evaluate";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_range1";
    send_key "alt-f4";

    assert_screen "imagemagick_trans_threshold";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_range2";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_range3";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_range4";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_range5";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_ice-sea";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_burnished";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_grassland";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_snow_scape";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_sunset";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_clip";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_crop";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_range1";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_range2";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_range3";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_range4";
    send_key "alt-f4";

    assert_screen "imagemagick_rgradient_range5";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_transparent";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_sigmoidal";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_trans_colorize";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_cosine";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_peak";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_bands";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_diagonal";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_srt";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_swirl";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_trapezoid";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_arc";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_circle";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_angle_even";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_angle_masked";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_angle_odd";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_triangle";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_bird";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_venetian";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_vent_diag";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_colormap";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_rainbow";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_hue_polar";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_rainbow_2";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_resize";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_resize2";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_resize3";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_resize4";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_resize5";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_rs_rainbow";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_interpolated";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_clut";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_clut_recolored";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_bilinear";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_mesh";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_catrom";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_linear";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_x4";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_cos";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_radial";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_spherical";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_quad2";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_fx_angular";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_inverse_alt";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_shepards_alt";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_inverse_RGB";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_inverse_RGB_Hue";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_barycentric";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_triangle";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_triangle_2";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_0";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_gradient";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_gradient_2";
    send_key "alt-f4";

    assert_screen "imagemagick_diagonal_gradient";
    send_key "alt-f4";

    assert_screen "imagemagick_diagonal_gradient_2";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bary_two_point";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_scale";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_math";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_equiv";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_shifted";
    send_key "alt-f4";

    assert_screen "imagemagick_gradient_chopped";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bilinear";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_bilin_0";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_voronoi";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_voronoi_ssampled";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_voronoi_smoothed";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_voronoi_blur";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_voronoi_gradient";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_inverse";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_inverse_near";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_inverse_far";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_inverse_stronger";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_0.5";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_1";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_2";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_3";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_8";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_shepards_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_rose_alpha_gradient";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_source";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_fill";
    send_key "alt-f4";

    assert_screen "imagemagick_shape_edge_pixels";
    send_key "alt-f4";

    assert_screen "imagemagick_shape_edge_in_lights";
    send_key "alt-f4";

    assert_screen "imagemagick_shape_in_lights";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_blur_simple";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_blur_pyramid";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_lines_near_source";
    send_key "alt-f4";

    assert_screen "imagemagick_sparse_lines_near";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_smooth";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_paint";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_emboss";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_sharp";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_seeded";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_rnd1";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_rnd2";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_rnd3";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_rnd4";
    send_key "alt-f4";

    assert_screen "imagemagick_plasma_rnd5";
    send_key "alt-f4";

    assert_screen "imagemagick_random_mask";
    send_key "alt-f4";

    assert_screen "imagemagick_random_black";
    send_key "alt-f4";

    assert_screen "imagemagick_random_white";
    send_key "alt-f4";

    assert_screen "imagemagick_random_1";
    send_key "alt-f4";

    assert_screen "imagemagick_random_trans";
    send_key "alt-f4";

    assert_screen "imagemagick_random_3";
    send_key "alt-f4";

    assert_screen "imagemagick_random_5";
    send_key "alt-f4";

    assert_screen "imagemagick_random_10";
    send_key "alt-f4";

    assert_screen "imagemagick_random_20";
    send_key "alt-f4";

    assert_screen "imagemagick_random_0_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_1_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_3_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_5_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_10_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_20_gray";
    send_key "alt-f4";

    assert_screen "imagemagick_random_0_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_1_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_3_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_5_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_10_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_20_thres";
    send_key "alt-f4";

    assert_screen "imagemagick_random_5_blobs";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_1";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_2";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_4";
    send_key "alt-f4";

    assert_screen "imagemagick_random_enhanced";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_4e";
    send_key "alt-f4";

    assert_screen "imagemagick_random_sigmoidal";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_4s";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3e000";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3e090";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3e180";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3e270";
    send_key "alt-f4";

    assert_screen "imagemagick_ripples_3.5e";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_size";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_over";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_draw";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_reset";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_distort_sized";
    send_key "alt-f4";

    assert_screen "imagemagick_offset_tile";
    send_key "alt-f4";

    assert_screen "imagemagick_offset_pattern";
    send_key "alt-f4";

    assert_screen "imagemagick_offset_tile_fill";
    send_key "alt-f4";

    assert_screen "imagemagick_offset_pattern_fail";
    send_key "alt-f4";

    assert_screen "imagemagick_offset_pattern_good";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_clone";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_clone_flip";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mpr";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mpr_reset";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mpr_fill";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_distort";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_distort_checks";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_distort_polar";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_default";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_hexagons";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_colored";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_color_checks";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_color_hexagons";
    send_key "alt-f4";

    assert_screen "imagemagick_pattern_distorted";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mod_failure";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mod_vpixels";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_slanted_bricks";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_mod_success";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_circles";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_hexagons";
    send_key "alt-f4";

    assert_screen "imagemagick_tiled_hexagons";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_line";
    send_key "alt-f4";

    assert_screen "imagemagick_tile_hex_lines";
    send_key "alt-f4";

    assert_screen "imagemagick_tiled_hex_lines";
    send_key "alt-f4";

    # clean-up
    assert_script_run "rm bg_script.sh";

    type_string "exit\n";
}
1;
