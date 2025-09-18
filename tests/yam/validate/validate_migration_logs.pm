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
    script_run 'tar zcvf /tmp/cache_wicked_config.tar.gz /var/cache/wicked_config/*';
    upload_logs("/tmp/cache_wicked_config.tar.gz", failok => 1);
    script_run 'tar zcvf /tmp/cache_udev_rules.tar.gz /var/cache/udev_rules/*';
    upload_logs("/tmp/cache_udev_rules.tar.gz", failok => 1);
    script_run("tar czvf /tmp/udev_rules.tar.gz /etc/udev/rules.d/*", {timeout => 60});
    upload_logs("/tmp/udev_rules.tar.gz", failok => 1);

    if (script_run("cat /var/log/distro_migration.log | grep -i -E \"migration failed|aborting migration\"") == 0) {
        record_info("Migration failed", script_output("cat /var/log/distro_migration.log | grep -i -E \"migration failed|aborting migration\" -B50"), result => 'fail');
        die("Migration failed");
    }
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');
}

1;
