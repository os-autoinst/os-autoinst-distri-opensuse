use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # 550_reboot_lxde
    wait_idle;

    #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
    x11_start_program("xterm");
    script_sudo "/sbin/reboot";
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
