# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: GraphicMagick testsuite
# Maintainer: Ivan Lausuch <ilausuch@suse.com>

use base 'x11test';
use testapi;
use strict;
use warnings;
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

    type_string "gm display quadrants500x500.png\n";
    assert_screen('open_an_image', 90);
    send_key 'alt-f4';

    type_string "gm display -geometry 300x300+200+200! quadrants500x500.png\n";
    assert_screen('open_an_image_window_location', 90);
    send_key 'alt-f4';

    type_string "gm display frame*.tiff\n";
    assert_screen('open_an_image_directory_1', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_2', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_3', 90);
    send_key 'spc';
    assert_screen('open_an_image_directory_4', 90);
    send_key 'alt-f4';

    type_string "gm convert noise_blur_10.png HISTOGRAM:- | gm display -\n";
    assert_screen('open_an_image_histogram', 90);
    send_key 'alt-f4';

    type_string "exit\n";
    send_key 'alt-f4';
}

1;
