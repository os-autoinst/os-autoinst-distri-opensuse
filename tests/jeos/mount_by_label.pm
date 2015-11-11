use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    validate_script_output "btrfs filesystem show / | grep -o \"Label: '.*'\"", sub { /^Label: '.*'$/ }
}

1;
