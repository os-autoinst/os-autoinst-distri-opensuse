# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ntp
# Summary: Basics ntp test - add ntp servers, obtain time
# Maintainer: : QE Security <none@suse.de>
#
# This test has been adapted from console/ntp.pm and changed to clean up after
# itself, which is required if we want to run chrony test afterwards, since it
# fails when ntpd is installed.

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use services::ntpd;
use serial_terminal qw(select_serial_terminal);
use Utils::Logging 'save_and_upload_log';
use version_utils 'is_sle';
use registration 'add_suseconnect_product';


sub run {
    select_serial_terminal;
    add_suseconnect_product('sle-module-legacy') if is_sle('>=15-SP5');
    services::ntpd::install_service();
    services::ntpd::enable_service();
    services::ntpd::start_service();
    services::ntpd::check_config();
    services::ntpd::config_service();
    services::ntpd::check_service();
    services::ntpd::check_function();
    services::ntpd::disable_service();
    services::ntpd::stop_service();
    services::ntpd::remove_service();
}

sub post_fail_hook {
    assert_script_run 'cp /etc/ntp.conf.bkp /etc/ntp.conf' if (script_run('test -f /etc/ntp.conf.bkp') == 0);
    upload_logs '/var/log/ntp';
    save_and_upload_log('journalctl --no-pager -o short-precise', 'journalctl.txt');
}

sub post_run_hook {
    assert_script_run 'cp /etc/ntp.conf.bkp /etc/ntp.conf' if (script_run('test -f /etc/ntp.conf.bkp') == 0);
}

1;
