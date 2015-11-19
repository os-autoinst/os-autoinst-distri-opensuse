use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    validate_script_output "parted -ml | grep dev | head -1 | cut -d':' -f6", sub { /^gpt$/ }
}

1;
