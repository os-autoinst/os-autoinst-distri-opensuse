# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the snapshot "after install" is not present.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    my $snapper_description = script_output("snapper list --columns description");
    if ($snapper_description =~ /after\sinstallation/) {
        die "After installation snapshot is present, check log";
    }
}

1;
