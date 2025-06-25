package installbasetest;
use base "opensusebasetest";
use strict;
use warnings;

# All steps in the installation are 'fatal'.

# Overwrite default post_run_hook
sub post_run_hook {
    ;
}

sub test_flags {
    return {fatal => 1};
}

1;
