# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate logs after migration to sle 16.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

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

    my $fatal_errors = script_output("cat /var/log/distro_migration.log | grep -i -E \"migration failed|aborting migration\" -B50", proceed_on_failure => 1);
    if ($fatal_errors) {
        record_info("Migration failed", $fatal_errors, result => 'fail');
        die("Migration failed");
    }

    my $minor_errors = script_output("cat /var/log/distro_migration.log | grep -ivE \"\\-errors?|errors?\\-|error=''\" | grep -iE \"failed|failure|error\" -B50", proceed_on_failure => 1);
    record_info("Minor errors", $minor_errors, result => 'fail') if ($minor_errors);
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');
}

1;
