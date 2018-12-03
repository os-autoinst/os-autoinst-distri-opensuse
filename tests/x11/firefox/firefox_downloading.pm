# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436106: Firefox: Downloading
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11test";
use testapi;
use version_utils 'is_sle';

my $dl_link_01 = "http://mirrors.kernel.org/opensuse/distribution/leap/42.2/iso/openSUSE-Leap-42.2-DVD-x86_64.iso";
my $dl_link_02 = "http://mirrors.kernel.org/opensuse/distribution/leap/42.3/iso/openSUSE-Leap-42.3-DVD-x86_64.iso";

sub dl_location_switch {
    my ($tg) = @_;
    wait_screen_change {
        send_key "alt-e";
    };
    send_key "n";
    assert_screen('firefox-preferences');

    if ($tg ne "ask") {
        send_key "alt-shift-v";    #"Save files to Downloads"
    }
    else {
        send_key "alt-shift-a";    #"Always ask me where to save files"
    }
}

sub dl_save {
    my ($self, $link) = @_;
    $self->firefox_open_url($link);

    # check if downloading content open with default application
    assert_screen ['firefox-downloading-openwith', 'firefox-downloading-save_enabled'], 30;
    if (match_has_tag 'firefox-downloading-openwith') {
        send_key "alt-s";
    }
    assert_and_click("firefox-downloading-save_enabled", "left", 90);
    # wait a little time at the beginning of the download to avoid busy disk writing
    wait_still_screen 3, 6;
}

# the changes of shift-f10 context menu and its shortcut keys certainly rely on the
# actual downloading status, slow down the operations for pause, cancel and resume
sub dl_pause {
    dl_menu();
    send_key "p";
}

# firefox 60.2 does not have option or shortcut to cancel only button
sub dl_cancel {
    assert_and_click('firefox-downloading-cancel-button');
}

sub dl_resume {
    dl_menu();
    send_key "r";
    wait_still_screen 3, 6;
}

sub dl_menu {
    wait_still_screen 3,                                   6;
    send_key_until_needlematch 'firefox-downloading-menu', 'shift-f10', 3, 3;
    wait_still_screen 3,                                   6;
}

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;

    dl_location_switch("ask");
    dl_save($self, $dl_link_01);
    assert_and_click('firefox-downloading-saving_dialog', 'left', 90);
    assert_screen('firefox-downloading-library', 90);

    # Pause
    dl_pause();
    assert_screen 'firefox-downloading-paused';

    # Resume
    dl_resume();

    # It have to use context menu to identify if downloading resumed, (gray "pause")
    # because there is no obvious specific elements when download is in on going.
    dl_menu();
    assert_screen 'firefox-downloading-resumed';
    send_key "esc";

    # Cancel
    dl_cancel();
    assert_screen 'firefox-downloading-canceled';

    # Retry
    send_key "ret";
    dl_menu();
    assert_screen 'firefox-downloading-resumed';
    send_key "esc";

    # Remove from history
    dl_cancel();
    dl_menu();
    send_key "e";    #"Remove From History"
    assert_screen 'firefox-downloading-blank_list';

    # Close download library and wait a little time
    send_key "alt-f4";
    wait_still_screen 3, 6;

    # Multiple files downloading
    dl_location_switch("save");

    dl_save($self, $dl_link_01);
    dl_save($self, $dl_link_02);

    send_key "ctrl-shift-y";
    assert_screen 'firefox-downloading-multi';

    # Clear downloads
    dl_cancel();
    send_key "down";
    dl_cancel();

    dl_menu();
    # clear downloads, sometimes one d does not clear the list
    send_key_until_needlematch 'firefox-downloading-blank_list', 'd', 3, 3;

    send_key "alt-f4";
    send_key "spc";

    $self->exit_firefox;
}
1;
