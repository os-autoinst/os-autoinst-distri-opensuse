# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: upload logs from openscap remediation
#
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    foreach my $file (split("\n", script_output('ls /var/log/ssg-apply/*'))) {
        upload_logs("$file");
    }
}

1;
