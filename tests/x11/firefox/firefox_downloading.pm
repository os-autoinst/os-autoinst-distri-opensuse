# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1436106: Firefox: Downloading
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open firefox preferences, change download to "Always ask you where to save
# files"
# - Open url "http://mirrors.kernel.org/opensuse/distribution/leap/15.4/iso/openSUSE-Leap-15.4-DVD-x86_64-Media.iso"
# - Show download window
# - Pause download
# - Resume download and check
# - Cancel download
# - Retry download
# - Cancel download and remove from history
# - Open firefox preferences, change download to save files by default
# - Open
# url "http://mirrors.kernel.org/opensuse/distribution/leap/15.3/iso/openSUSE-Leap-15.3-3-DVD-aarch64-Media.iso"
# and "http://mirrors.kernel.org/opensuse/distribution/leap/15.3/iso/openSUSE-Leap-15.3-3-DVD-x86_64-Media.iso"
# - Open download library and check both downloads running
# - Cancel both downloads
# - Exit firefox

# Maintainer: wnereiz <wnereiz@github>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils 'is_sle';

my $dl_link_01 = "http://mirrors.kernel.org/opensuse/distribution/leap/15.3/iso/openSUSE-Leap-15.3-3-DVD-aarch64-Media.iso";
my $dl_link_02 = "http://mirrors.kernel.org/opensuse/distribution/leap/15.3/iso/openSUSE-Leap-15.3-3-DVD-x86_64-Media.iso";

sub dl_location_switch {
    my ($self, $tg) = @_;

    $self->firefox_preferences;
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
    assert_and_click('firefox-downloading-save_enabled', timeout => 90);
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
    wait_still_screen(2, 4);
}

sub dl_resume {
    dl_menu();
    send_key "r";
    wait_still_screen 3, 6;
}

sub dl_menu {
    # sometimes menu does close due high load or some worker hickup, check & open menu again if not present
    for (1 .. 2) {
        wait_still_screen 3, 6;
        send_key_until_needlematch 'firefox-downloading-menu', 'shift-f10', 4, 3;
    }
}

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;

    dl_location_switch($self, "ask");
    dl_save($self, $dl_link_01);
    send_key 'ctrl-shift-y';
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
    dl_location_switch($self, "save");

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
    send_key_until_needlematch 'firefox-downloading-blank_list', 'd', 4, 3;

    send_key "alt-f4";
    send_key "spc";

    $self->exit_firefox;
}
1;
