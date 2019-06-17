# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: GOOGLE Chrome: attempt to install and run google chrome
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $arch;
    if (check_var('ARCH', 'i586')) {
        $arch = "i386";
    }
    else {
        $arch = "x86_64";
    }
    my $chrome_url = "https://dl.google.com/linux/direct/google-chrome-stable_current_$arch.rpm";
    select_console('x11');

    mouse_hide;

    x11_start_program('xterm');

    # install the google key first
    become_root;
    assert_script_run "rpm --import https://dl.google.com/linux/linux_signing_key.pub";

    # validate it's properly installed
    script_run "rpm -qi gpg-pubkey-7fac5991-*";
    assert_screen 'google-key-installed';

    zypper_call "in $chrome_url";
    save_screenshot;
    # closing xterm
    send_key "alt-f4";

    # avoid async keyring popups
    x11_start_program('google-chrome --password-store=basic', target_match => 'chrome-default-browser-query');
    # we like to preserve the privacy of the non-human openqa workers ;-)
    assert_and_click 'chrome-do_not_send_data' if match_has_tag 'chrome-default-browser-query-send-data';
    assert_and_click 'chrome-default-browser-query';

    assert_screen 'google-chrome-main-window', 50;

    send_key "ctrl-l";
    sleep 1;
    type_string "about:\n";
    assert_screen 'google-chrome-about', 15;

    send_key "alt-f4";
}

1;
