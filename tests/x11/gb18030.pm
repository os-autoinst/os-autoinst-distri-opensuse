# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gb18030
# Summary: GB18030-2005 standard certification
# - Download test text file from datadir
# - Configure gedit and system fonts
# - Launch gedit and open test text file
# - Fullscreen and compare with needle
# - Scroll to next screen and repeat
# - Exit gedit, erase test file
# More documentation about how to automatically update gb18030 needles is located at:
#   data/x11/gb18030/README.md
# Maintainer: Zhaocong <zcjia@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use x11utils;

sub test_gb18030_file {
    my $filename = shift;
    my $needlenumber = shift;

    x11_start_program('gedit ' . $filename . '.txt', target_match => 'gedit-gb18030-' . $filename . '-opened');
    wait_still_screen;

    send_key("f11");
    wait_still_screen;

    for (my $n = 1; $n <= $needlenumber; $n++) {
        assert_screen('gb18030-' . $filename . '-page-' . $n);
        send_key("pgdn");
        # move the cursor up for better alignment
        send_key("up");
        sleep(1);
    }

    wait_screen_change { send_key "ctrl-q"; };

    # clean up saved file
    x11_start_program("rm " . $filename . ".txt", valid => 0);
}

sub run {
    my ($self) = @_;

    ensure_installed('gedit');
    # download test text file from x11 data directory
    x11_start_program("xterm");
    enter_cmd("wget " . autoinst_url . "/data/x11/gb18030/{double,four}.txt");

    enter_cmd("gsettings set org.gnome.gedit.preferences.encodings candidate-encodings \"['GB18030', 'UTF-8']\"");
    enter_cmd("gsettings set org.gnome.gedit.preferences.editor use-default-font false");
    enter_cmd("gsettings set org.gnome.gedit.preferences.editor editor-font 'Noto Sans Mono CJK SC 16'");
    enter_cmd("gsettings set org.gnome.gedit.preferences.editor highlight-current-line false");
    enter_cmd("gsettings set org.gnome.gedit.preferences.editor display-line-numbers false");
    # the blinking cursor affects needle matching percentage, disable it
    enter_cmd("gsettings set org.gnome.desktop.interface cursor-blink false");

    # the following fonts preparing steps are documented at:
    # https://confluence.suse.com/display/~kailiu/How+to+prepare+the+system+for+GB18030-2005+certification
    become_root;
    zypper_call("rm arphic-ukai-fonts arphic-uming-fonts baekmuk-*-fonts noto-*-tc* noto-*-jp* noto-*-kr* wqy* adobe-sourcecodepro-fonts xorg-x11-fonts-converted", exitcode => [0, 104]);
    zypper_call("in noto-sans-sc-mono-fonts");
    script_run("ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/");

    enter_cmd("exit");
    enter_cmd("exit");

    test_gb18030_file('double', 45);
    test_gb18030_file('four', 9);
}

1;
