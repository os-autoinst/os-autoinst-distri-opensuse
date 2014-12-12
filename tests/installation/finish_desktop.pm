use base "installbasetest";
use testapi;

# using this as base class means only run when an install is needed
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

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

1;
# vim: set sw=4 et:
