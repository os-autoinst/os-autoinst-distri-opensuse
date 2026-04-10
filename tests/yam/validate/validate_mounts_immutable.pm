# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate if / is mounted ro and /var is on an own partition.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    my ($root_device) = (script_output("findmnt / -n -O ro") =~ m|/ (\S+)\[|)
      or die "Didn't find a root partition that is mounted read-only.";

    my ($var_device) = (script_output("findmnt /var -n") =~ m|/var (\S+) |)
      or die "Didn't find a root partition that is mounted read-only.";

    my $var_fs = script_output("findmnt /var -n");
    if ($var_fs =~ m/\/var (?<var>\S+) /) {
        $var_device = $+{var};
    }
    else {
        die "Couldn't find a mount point for /var.";
    }

    die "/var is not mounted on an extra partition." if $root_device eq $var_device;
}

1;
