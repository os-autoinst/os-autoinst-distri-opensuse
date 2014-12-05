use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # 550_reboot_xfce
    wait_idle;
    send_key "alt-f4"; # open logout dialog
    assert_screen 'logoutdialog', 15;
    send_key "tab";    # reboot
    save_screenshot;
    send_key "ret";    # confirm
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
