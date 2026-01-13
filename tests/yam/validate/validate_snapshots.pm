# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the snapshot "after install" is not present due to SLE 16 uses selinux.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    script_run("snapper list");
    my $snapper_description = script_output("snapper list --columns description");
    if ($snapper_description =~ /after\sinstallation/) {
        die "After installation snapshot is present, check the logs";
    }
}

1;
