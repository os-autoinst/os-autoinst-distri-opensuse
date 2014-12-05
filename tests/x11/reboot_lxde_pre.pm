use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    # 550_reboot_lxde
    wait_idle;

    #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
    x11_start_program("xterm");
    script_sudo "/sbin/reboot";
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
