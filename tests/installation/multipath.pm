use base "opensusebasetest";
use strict;
use testapi;

sub run {
    assert_screen "enable-multipath", 15;
    send_key "alt-y";
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
