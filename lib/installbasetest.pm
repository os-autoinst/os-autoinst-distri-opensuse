package installbasetest;
use base "opensusebasetest";

use bmwqemu;

# All steps in the installation are 'fatal'.

sub test_flags() {
    return { 'fatal' => 1 };
}

sub is_applicable() {
    return installbasetest_is_applicable;
}

1;
# vim: set sw=4 et:
