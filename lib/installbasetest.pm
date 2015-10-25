package installbasetest;
use base "opensusebasetest";

# All steps in the installation are 'fatal'.

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
