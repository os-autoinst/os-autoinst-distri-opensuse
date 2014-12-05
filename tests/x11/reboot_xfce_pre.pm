use base "x11test";
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

# override post work, we don't need to check
# desktop screenshot at the end
sub post_run_hook {
    my ($self) = @_;
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
