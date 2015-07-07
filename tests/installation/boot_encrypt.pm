use strict;
use base "installbasetest";
use utils;

sub run() {
    unlock_if_encrypted;
}

1;

# vim: set sw=4 et:
