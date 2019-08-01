# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that users are imported and not created when a system is re-installed with autoyast
# by checking for non-existence of .bashrc in /var/lib/{gdm,empty,polkit,nobody,pulseaudio}.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use scheduler 'get_test_data';

sub run {
    my $test_data = get_test_data();
    my $errors;
    foreach my $path (@{$test_data->{paths}}) {
        if (!script_run("test -f $path")) {
            if ($path eq '/var/lib/pulseaudio/.bashrc') {
                return record_soft_failure("bsc#1143205 - pulseaudio bash profile shouldn't exist");
            }
            $errors .= "$path should not exist\n";
        }
    }
    die "Bash profiles created instead of being imported (bsc#1130811):\n $errors" if ($errors);
    record_info("Import OK", "No wrong .bashrc files found in paths provided");
}

1;

