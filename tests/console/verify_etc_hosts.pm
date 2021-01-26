# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks entries in /etc/hosts based on test_data from the
#          yaml schedule.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use scheduler;
use utils;

sub run {
    my @entries = @{get_test_suite_data()->{hostname_entries}};
    select_console 'root-console';

    foreach (@entries) {
        my $entry = "$_->{ip}\s+$_->{name}";
        $entry .= $_->{aliases} ? "\s+$_->{aliases}" : '';
        assert_script_run("grep -P "$entry" /etc/hosts");
    }
}

1;
