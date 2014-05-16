use base "basetest";
use bmwqemu;

# using this as base class means only run when an install is needed
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{LIVETEST};
}

sub run() {
    my $self = shift;

    # live may take ages to boot
    my $timeout = 300;
    if ( $vars{'RESCUECD'} ) {
        assert_screen  'displaymanager', $timeout;
        send_key "tab";
        sleep 2;
        send_key "tab";
        sleep 2;
        send_key "tab";
        sleep 2;
        send_key "ret";
        $timeout = 60;
    }
    assert_screen  "desktop-at-first-boot", $timeout;

    ## duplicated from second stage, combine!
    if ( check_var( 'DESKTOP', 'kde' ) ) {
        send_key "esc";
        sleep 2;
        $self->take_screenshot();
    }
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
