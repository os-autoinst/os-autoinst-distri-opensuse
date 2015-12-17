use base "opensusebasetest";
use testapi;
use utils;

sub run() {
    wait_idle;
    send_key "alt-f4";    # open logout dialog
    assert_screen 'logoutdialog', 15;
    send_key "tab";       # reboot
    save_screenshot;
    send_key "ret";       # confirm
    wait_boot;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}
1;

# vim: set sw=4 et:
