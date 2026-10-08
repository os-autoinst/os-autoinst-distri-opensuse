# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ntp
# Summary: Basics ntp test - add ntp servers, obtain time
# Maintainer: : QE Security <none@suse.de>
#
# This test has been adapted from console/ntp.pm and changed to clean up after
# itself, which is required if we want to run chrony test afterwards, since it
# fails when ntpd is installed.
# Tags: poo#207477

use Mojo::Base 'consoletest';
use testapi;
use utils;
use services::ntpd;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'save_and_upload_log';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);
use serial_terminal 'select_text_console';

sub run {
    select_text_console;
    add_suseconnect_product('sle-module-legacy') if is_sle('>=15-SP4') && is_sle('<16.0');
    add_suseconnect_product(get_addon_fullname('phub')) if (is_phub_ready() && is_sle('>=16.0'));
    assert_script_run('zypper --gpg-auto-import-keys refresh') if is_sle('>=16.0');
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
