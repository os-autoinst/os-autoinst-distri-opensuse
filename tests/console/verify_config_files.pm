# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Module allows validation of generic configuration files.
# Test data should be defined in the following format:
#  configuration_files:
#    - path: /etc/hosts
#      entries:
#        - 'new.entry.de\t10.226.154.19 h999uz'
#    - path: /etc/chrony.conf
#      entries:
#        - pool ntp.suse.de iburst
# NOTE: grep -P is used for validation, therefore perl regexp syntax can be
#       used in the entries
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use scheduler;
use utils;

sub run {
    select_console 'root-console';

    my $test_data = get_test_suite_data();
    # Accumulate errors for all checks
    my $errors = '';
    foreach my $file (@config_files) {
        foreach my $entry (@{$file->{entries}}) {
            if (script_run("grep -P \"$entry\" $file->{path}") != 0) {
                $errors .= "Entry '$entry' is not found in '$file->{path}'.\n";
            }
        }
    }

    die "Configuration files validation failed:\n$errors" if $errors;
}

1;
