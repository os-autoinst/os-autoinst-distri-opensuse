use base "opensusebasetest";
use strict;
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{MEMTEST};
}

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    for ( 1 .. 6 ) {
	last if check_screen "inst-onmemtest", 2;
	send_key "down";
    }
    assert_screen "inst-onmemtest", 3;
    send_key "ret";
    assert_screen "pass-complete", 700;
    send_key "esc";
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
