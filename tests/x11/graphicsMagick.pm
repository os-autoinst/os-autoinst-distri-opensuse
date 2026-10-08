# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: GraphicsMagick
# Summary: GraphicMagick testsuite
# Maintainer: Ivan Lausuch <ilausuch@suse.com>

use Mojo::Base 'x11test';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils 'zypper_call';
use x11utils qw(default_gui_terminal close_gui_terminal);

my $workdir;

sub run {
    my $self = shift;

    select_console "root-console";
    script_run("pkill Xwayland");
    zypper_call('-q in GraphicsMagick');

    select_console "x11";
    x11_start_program(default_gui_terminal);

    $workdir = script_output 'mktemp -d';
    assert_script_run("pushd $workdir");

    record_info("INFO", "Step 1. Runs command line tests");
    assert_script_run "wget --quiet " . data_url('graphicsmagick/test.sh') . " -O test.sh";
    assert_script_run "chmod +x test.sh";
    my $command = "./test.sh " . data_url('graphicsmagick') . " |& tee run.log";
    assert_script_run("$command", 3 * 60);

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
    upload_logs("run.log");
    assert_script_run("popd");
    assert_script_run("rm -rf $workdir");

    close_gui_terminal;
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    upload_logs("${workdir}/run.log");
    $self->SUPER::post_fail_hook();
}

1;
