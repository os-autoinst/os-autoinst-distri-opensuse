use base "basetest";
use strict;
use bmwqemu;

sub is_applicable() {
    return $envs->{MEDIACHECK};
}

sub run {
    my $self = shift;
    assert_screen  "mediacheck-ok", 300 ;
    send_key "ret";
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
