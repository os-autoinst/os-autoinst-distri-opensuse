# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate logs after migration to sle 16.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;
use utils 'upload_folders';

sub run {
    select_console 'root-console';

    upload_logs("/var/log/distro_migration.log", failok => 1);
    die("Migration failed") if (script_run("cat /var/log/distro_migration.log | grep -i \"migration failed\"") == 0);
}

sub post_fail_hook {
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');
}

1;
