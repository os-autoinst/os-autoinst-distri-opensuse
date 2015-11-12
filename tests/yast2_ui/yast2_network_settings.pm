use base "y2x11test";
use testapi;

sub run() {
    my $self   = shift;
    my $module = "lan";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 60;
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:
