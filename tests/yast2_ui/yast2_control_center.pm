use base "y2x11test";
use testapi;

sub run() {
    my $self = shift;

    $self->launch_yast2_module_x11;
    assert_screen 'yast2-control-center-ui', 30;
    send_key "alt-f4";    # OK => Exit
}

1;
# vim: set sw=4 et:
