use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $check_vim  = "zypper -q info vim | grep 'Installed:' | cut -d' ' -f2";
    my $check_data = "zypper -q info vim-data | grep -v '^\$'";

    validate_script_output $check_vim,  sub { /^Yes$/ };
    validate_script_output $check_data, sub { /^package .* not found\.$/ };
}

1;
