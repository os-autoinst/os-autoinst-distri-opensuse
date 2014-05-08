use base "basetest";
use bmwqemu;

# using this as base class means only run when an install is needed
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $ENV{LIVETEST};
}

sub run() {
    my $self = shift;

    # live may take ages to boot
    my $timeout = 300;
    if ( $ENV{'RESCUECD'} ) {
        waitforneedle( 'displaymanager', $timeout );
        send_key "tab";
        sleep 2;
        send_key "tab";
        sleep 2;
        send_key "tab";
        sleep 2;
        send_key "ret";
        $timeout = 60;
    }
    waitforneedle( "desktop-at-first-boot", $timeout );

    ## duplicated from second stage, combine!
    if ( checkEnv( 'DESKTOP', 'kde' ) ) {
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
