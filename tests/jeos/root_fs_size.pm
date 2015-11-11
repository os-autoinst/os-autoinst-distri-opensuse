use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    validate_script_output "df --output=size -BG / | sed 1d | tr -d ' '", sub { /^24G$/ }
}

1;
