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

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console('x11');
    x11_start_program("xterm");
    become_root;
    type_string "while pgrep packagekitd; do pkcon quit; sleep 1; done \n";
    zypper_call("in ImageMagick");
    type_string "exit\n";

    type_string "wget --quiet " . data_url('imagemagick/bg_script.sh') . " -O bg_script.sh \n";
    type_string "chmod +x bg_script.sh; ./bg_script.sh " . data_url('imagemagick/bg_script.sh') . " \n";

    assert_screen("imagemagick_test", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_shape", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_fractal2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_weave", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_bg", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_aqua", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_water", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_rings", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_disks", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tree", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_canvas_khaki", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_canvas_wheat", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_canvas_salmon", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_canvas_tomato", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_canvas_rose_red", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_levelc", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_colorize", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_sparse", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_reset", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_flatten", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_extent", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_border", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_fx_constant", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_fx_math", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_semitrans", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_pick_fx", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_pick_sparse", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_pick_draw", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_pick_distort", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_threshold", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_level", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_fx", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_evaluate", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_gamma", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_posterize", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_black_alpha", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_threshold", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_level", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_fx", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_evaluate", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_posterize", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_white_alpha", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_alpha", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_compose", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_color_matte", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_fx", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_evaluate", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_threshold", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_trans_fx_alpha_off", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_yellow_gamma", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_grey_level", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_range1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_range2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_range3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_range4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_range5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_ice-sea", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_burnished", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_grassland", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_sunset", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_snow_scape", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_clip", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_crop", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_range1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_range2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_range3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_range4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rgradient_range5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_transparent", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_trans_colorize", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_sigmoidal", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_cosine", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_peak", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_bands", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_diagonal", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_srt", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_swirl", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_trapezoid", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_arc", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_circle", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_angle_even", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_angle_odd", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_angle_masked", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_triangle", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_bird", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_venetian", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_vent_diag", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_colormap", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_rainbow", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_rainbow_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_hue_polar", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_resize", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_resize2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_resize3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_resize4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_resize5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_rs_rainbow", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_interpolated", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_clut_recolored", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_clut", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_bilinear", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_catrom", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_mesh", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_linear", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_x4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_cos", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_radial", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_spherical", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_quad2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_fx_angular", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_inverse_alt", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_shepards_alt", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_inverse_RGB", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_inverse_RGB_Hue", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_barycentric", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_triangle", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_triangle_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_0", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_gradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_gradient_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_diagonal_gradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_diagonal_gradient_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bary_two_point", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_scale", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_equiv", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_math", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_shifted", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_gradient_chopped", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bilinear", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_bilin_0", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_voronoi", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_voronoi_ssampled", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_voronoi_smoothed", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_voronoi_blur", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_voronoi_gradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_inverse", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_inverse_near", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_inverse_far", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_inverse_stronger", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_0.5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_8", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_shepards_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_rose_alpha_gradient", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_source", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_fill", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_shape_edge_pixels", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_shape_edge_in_lights", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_shape_in_lights", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_blur_simple", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_blur_pyramid", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_lines_near_source", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_sparse_lines_near", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_smooth", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_paint", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_emboss", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_sharp", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_seeded", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_rnd1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_rnd2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_rnd3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_rnd4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_plasma_rnd5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_mask", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_black", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_white", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_trans", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_5", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_10", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_20", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_0_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_1_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_3_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_5_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_10_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_20_gray", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_0_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_1_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_3_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_5_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_10_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_20_thres", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_5_blobs", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_1", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_2", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_4", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_enhanced", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_4e", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_random_sigmoidal", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_4s", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3e000", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3e090", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3e180", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3e270", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_ripples_3.5e", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_size", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_over", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_draw", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_reset", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_distort_sized", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_offset_tile", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_offset_pattern", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_offset_tile_fill", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_offset_pattern_fail", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_offset_pattern_good", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_clone", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_clone_flip", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mpr", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mpr_reset", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mpr_fill", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_distort", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_distort_checks", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_distort_polar", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_default", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_hexagons", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_colored", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_color_checks", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_color_hexagons", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_pattern_distorted", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mod_failure", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mod_vpixels", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_slanted_bricks", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_mod_success", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_circles", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_hexagons", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tiled_hexagons", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_line", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tile_hex_lines", 10);
    send_key "alt-f4";
    wait_idle;

    assert_screen("imagemagick_tiled_hex_lines", 10);
    send_key "alt-f4";
    wait_idle;

    type_string "exit\n";
}
1;
