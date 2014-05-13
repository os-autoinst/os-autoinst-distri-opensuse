use base "basetest";
use bmwqemu;

sub is_applicable() {
    return ( $vars{DESKTOP} eq "xfce" );
}

sub run() {
    my $self = shift;
    assert_screen "XFCE", 30;
    send_key "alt-c";    # close hint popup
    wait_idle;
}

1;
# vim: set sw=4 et:
