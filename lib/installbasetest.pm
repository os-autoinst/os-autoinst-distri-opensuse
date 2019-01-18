package installbasetest;
use base "opensusebasetest";
use strict;
use warnings;

# All steps in the installation are 'fatal'.

sub test_flags {
    return {fatal => 1};
}

1;
