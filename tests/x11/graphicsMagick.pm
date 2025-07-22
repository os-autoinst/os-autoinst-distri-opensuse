# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: GraphicsMagick
# Summary: GraphicMagick testsuite
# Maintainer: Ivan Lausuch <ilausuch@suse.com>

use base 'x11test';
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;

    select_console "x11";
    x11_start_program('xterm');

    become_root;

    zypper_call('-q in GraphicsMagick');

    record_info("INFO", "Step 1. Runs command line tests");
    assert_script_run "wget --quiet " . data_url('graphicsmagick/test.sh') . " -O test.sh";
    assert_script_run "chmod +x test.sh";
    assert_script_run("./test.sh " . data_url('graphicsmagick'), 3 * 60);

    record_info("INFO", "Step 2. Runs visual tests");

    enter_cmd "gm display quadrants500x500.png";
    assert_screen('open_an_image', 90);
    send_key 'alt-f4';

    enter_cmd "gm display -geometry 300x300+200+200! quadrants500x500.png";
    assert_screen('open_an_image_window_location', 90);
    send_key 'alt-f4';

    enter_cmd "gm display frame*.tiff";
    assert_screen('open_an_image_directory_1', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_2', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_3', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_4', 90);
    send_key 'alt-f4';

    enter_cmd "gm convert noise_blur_10.png HISTOGRAM:- | gm display -";
    assert_screen('open_an_image_histogram', 90);
    send_key 'alt-f4';

    enter_cmd "exit";
    send_key 'alt-f4';
}

1;
