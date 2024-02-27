# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: cloud init checker
# Maintainer: <jalausuch@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'save_and_upload_log';

sub post_boot_logs {
    save_and_upload_log('journalctl --no-pager -o short-precise', 'journal_after_boot.log');
    upload_logs('/etc/cloud/cloud.cfg');
    upload_logs('/var/log/cloud-init.log');
}

sub run {
    select_serial_terminal;
    record_info('VERSION', script_output('cloud-init -v'));
    record_info('STATUS', script_output('cloud-init status --long --wait', proceed_on_failure => 1));
    record_info('ANALYZE', script_output('cloud-init analyze show'));
    record_info('DUMP', script_output('cloud-init analyze dump'));
    record_info('BLAME', script_output('cloud-init analyze blame'));
    record_info('BOOT', script_output('cloud-init analyze boot', proceed_on_failure => 1));
    record_info('JOURNAL', script_output('journalctl --no-pager -u cloud-init'));
    validate_script_output('cat /tmp/cloud-message', sub { m/^cloud-init was here$/ });

    post_boot_logs;
}

sub post_run_hook {
    post_boot_logs;
}

sub post_fail_hook {
    post_boot_logs;
}


1;
