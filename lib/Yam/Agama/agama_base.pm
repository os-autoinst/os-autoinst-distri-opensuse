## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: base class for Agama tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::agama_base;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Utils::Logging 'save_and_upload_log';

sub post_fail_hook {
    select_console 'root-console';
    upload_agama_logs();
    upload_system_logs();
    upload_browser_automation_dumps();
}

sub test_flags {
    return {fatal => 1};
}

sub upload_traces {
    my ($dest, $sources) = ("/tmp/puppeteer-log.tar.gz", "log/");
    script_run("tar czf $dest $sources");
    upload_logs($dest, failok => 1);
}

sub upload_agama_logs {
    save_and_upload_log('agama logs store', "/tmp/agama-logs.tar.gz");
}

sub upload_system_logs {
    save_and_upload_log('journalctl -b > /tmp/journal.log', "/tmp/journal.log");
}

sub upload_browser_automation_dumps {
    upload_traces();
}

sub post_run_hook {
    select_console 'root-console';
    upload_agama_logs();
    upload_system_logs();
    upload_browser_automation_dumps();
}

1;
