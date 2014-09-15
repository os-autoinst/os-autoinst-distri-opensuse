use base "installbasetest";
use bmwqemu;

# using this as base class means only run when an install is needed
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{LIVETEST};
}

sub run() {
    my $self = shift;

    # live may take ages to boot
    my $timeout = 600;
    assert_screen "desktop-at-first-boot", $timeout;

    ## duplicated from second stage, combine!
    if ( check_var( 'DESKTOP', 'kde' ) ) {
        send_key "esc";
        sleep 2;
        assert_screen "generic-desktop", 10;
    }
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
