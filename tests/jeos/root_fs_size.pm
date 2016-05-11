# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $expected_size = "24G";
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $expected_size = "30G";
    }
    validate_script_output "df --output=size -BG / | sed 1d | tr -d ' '", sub { /^$expected_size$/ }
}

1;
