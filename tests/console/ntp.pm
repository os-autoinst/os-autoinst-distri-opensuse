# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ntp
# Summary: Basics ntp test - add ntp servers, obtain time
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use services::ntpd;
use serial_terminal qw(select_serial_terminal);
use Utils::Logging 'save_and_upload_log';

sub run {
    select_serial_terminal;
    services::ntpd::install_service();
    services::ntpd::enable_service();
    services::ntpd::start_service();
    services::ntpd::check_config();
    services::ntpd::config_service();
    services::ntpd::check_service();
    services::ntpd::check_function();
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
