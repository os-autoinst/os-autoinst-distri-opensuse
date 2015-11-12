use base "y2x11test";
use testapi;

sub run() {
    my $self   = shift;
    my $module = "sw_single";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 120;
    send_key "alt-a",                 1;     # Accept => Exit
}

1;
# vim: set sw=4 et:
