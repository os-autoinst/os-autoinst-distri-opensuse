# Case#1436106: Firefox: Downloading

use strict;
use base "x11test";
use testapi;

my $dl_link_01 = "http://download.opensuse.org/distribution/13.2/iso/openSUSE-13.2-DVD-x86_64.iso\n";
my $dl_link_02 = "http://download.opensuse.org/distribution/13.2/iso/openSUSE-13.2-DVD-i586.iso\n";

sub dl_location_switch {
    my ($tg) = @_;
    send_key "alt-e", 1;
    send_key "n";
    assert_screen('firefox-downloading-preferences', 15);

    if ($tg ne "ask") {
        send_key "alt-shift-v";    #"Save files to Downloads"
    }
    else {
        send_key "alt-shift-a";    #"Always ask me where to save files"
    }
    send_key "ctrl-w";
}

sub dl_save {
    my ($link) = @_;
    send_key "alt-d";
    type_string $link;

    # check if downloading content open with default application
    if (check_screen 'firefox-downloading-openwith', 20) {
        send_key "alt-s";
    }
    assert_and_click("firefox-downloading-save_enabled", "left", 60);
}

sub dl_pause {
    send_key "shift-f10";
    send_key "p";
}

sub dl_cancel {
    dl_pause();
    send_key "shift-f10";
    send_key "c";
}

sub run() {

    mouse_hide(1);

    # Clean & Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf Downloads/*;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 45);

    dl_location_switch("ask");

    dl_save($dl_link_01);

    assert_screen('firefox-downloading-saving_box', 25);
    send_key "alt-s";

    assert_and_click('firefox-downloading-saving_dialog', 'left', 20);

    assert_screen('firefox-downloading-library', 25);

    # Pause
    dl_pause();
    assert_screen('firefox-downloading-paused', 15);

    # Resume
    send_key "shift-f10", 1;
    send_key "r",         1;    #"Resume"

    # It have to use context menu to identify if downloading resumed, (gray "pause")
    # because there is no obvious specific elements when download is in on going.
    send_key "shift-f10";
    assert_screen('firefox-downloading-resumed', 15);
    send_key "esc";

    # Cancel
    dl_cancel();
    assert_screen('firefox-downloading-canceled', 15);

    # Retry
    send_key "ret", 1;
    send_key "shift-f10";
    assert_screen('firefox-downloading-resumed', 15);
    send_key "esc";

    # Remove from history
    dl_cancel();
    send_key "shift-f10", 1;
    send_key "e";    #"Remove From History"
    assert_screen('firefox-downloading-blank_list', 15);

    # Multiple files downloading
    send_key "alt-f4", 1;

    dl_location_switch("save");

    dl_save($dl_link_01);
    dl_save($dl_link_02);

    send_key "ctrl-shift-y";
    check_screen('firefox-downloading-multi', 5);

    # Clear downloads
    dl_cancel();
    send_key "down";
    dl_cancel();

    send_key "shift-f10", 1;
    send_key "d";    #"Clear Downloads"
    assert_screen('firefox-downloading-blank_list', 5);


    send_key "alt-f4", 1;
    send_key "spc";

    # Exit
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
