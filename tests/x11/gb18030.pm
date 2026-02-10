# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gb18030
# Summary: GB18030-2022 standard certification
# - Download test text file from datadir
# - Configure gedit/gnome-text-editor and system fonts
# - Launch gedit and open test text file
# - Fullscreen and compare with needle
# - Scroll to next screen and repeat
# - Exit gedit/gnome-text-editor, erase test file
# More documentation about how to automatically update gb18030 needles is located at:
#   data/x11/gb18030/README.md
# Maintainer: Zhaocong <zcjia@suse.com>

use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';
use x11utils;

sub test_gb18030_file {
    my $testprogram = shift;
    my $filename = shift;
    my $needlenumber = shift;

    x11_start_program($testprogram . ' ' . $filename . '.txt', target_match => $testprogram . '-gb18030-' . $filename . '-opened');
    wait_still_screen;

    # fullscreen gedit
    send_key("f11");
    wait_still_screen;

    for (my $n = 1; $n <= $needlenumber; $n++) {
        assert_screen('gb18030-' . $filename . '-page-' . $n);
        send_key("pgdn");
        # move the cursor up for better alignment
        send_key("up");
        sleep(2);
    }

    wait_screen_change { send_key "ctrl-q"; };

    # clean up saved file
    x11_start_program("rm " . $filename . ".txt", valid => 0);
}

sub gedit_test {
    ensure_installed('gedit');
    # download test text file from x11 data directory
    x11_start_program(default_gui_terminal);
    enter_cmd("wget " . autoinst_url . "/data/x11/gb18030/{double,four,gb18030-2022}.txt");

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
    zypper_call("rm arphic-ukai-fonts arphic-uming-fonts baekmuk-*-fonts noto-*-tc* noto-*-jp* noto-*-kr* wqy* adobe-sourcecodepro-fonts xorg-x11-fonts-converted xscreensaver", exitcode => [0, 104]);
    zypper_call("in noto-sans-sc-mono-fonts");
    script_run("ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/");

    enter_cmd("exit");
    sleep(1);
    enter_cmd("exit");

    test_gb18030_file('gedit', 'double', 45);
    test_gb18030_file('gedit', 'four', 9);
    test_gb18030_file('gedit', 'gb18030-2022', 1);
}

sub gnome_text_editor_test {
    # download test text file from x11 data directory
    x11_start_program(default_gui_terminal);
    enter_cmd("wget " . autoinst_url . "/data/x11/gb18030/gb18030-all.txt");
    # currently gnome-text-editor has trouble to automatically determine the encoding,
    # so we do a manual conversion here.
    enter_cmd("cat gb18030-all.txt | iconv -f gb18030 -t utf-8 > all.txt");

    # the following fonts preparing steps are documented at:
    # https://confluence.suse.com/spaces/~zcjia/pages/1989378440/Prepare+SLE16.0+for+GB18030-2022+certification
    enter_cmd("gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans SC 11'");
    enter_cmd("gsettings set org.gnome.desktop.interface font-name 'Noto Sans SC 11'");
    enter_cmd("gsettings set org.gnome.TextEditor spellcheck false");

    become_root;
    zypper_call("in google-noto-sans-sc-fonts");
    zypper_call("rm adobe-sourcecodepro-fonts google-noto-sans-jp-fonts google-noto-sans-kr-fonts google-noto-sans-tc-fonts", exitcode => [0, 104]);
    # removing adwaita-fonts will mess up the system interface, and require a reboot, so we keep it installed,
    # however this will affect the "user defined region" in gb18030.
    # zypper_call("rm adwaita-fonts");

    enter_cmd("exit");
    sleep(1);
    enter_cmd("exit");

    test_gb18030_file('gnome-text-editor', 'all', 29);
}

sub run {
    my ($self) = @_;

    if (is_sle("<16.0")) {
        gedit_test();
    } else {
        # for SLE16 and Tumbleweed
        gnome_text_editor_test();
    }
}

1;
