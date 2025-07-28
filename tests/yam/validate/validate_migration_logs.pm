# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate logs after migration to sle 16.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    upload_logs("/var/log/distro_migration.log", failok => 1);
}

1;
