use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    validate_script_output "cat /sys/kernel/kexec_crash_loaded", sub { /^0$/ }
}

1;
