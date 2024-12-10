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
    upload_agama_logs();
    upload_browser_automation_dumps();
}

sub upload_agama_logs {
    select_console 'root-console';
    save_and_upload_log('agama config show', "/tmp/agama-config.json", {timeout => 60});
    save_and_upload_log('agama logs store', "/tmp/agama-logs.tar.gz", {timeout => 60});
    save_and_upload_log('journalctl -b', "/tmp/journal.log", {timeout => 60});
}

sub upload_browser_automation_dumps {
    my ($dest, $sources) = ("/tmp/puppeteer-log.tar.gz", "log/");
    script_run("tar czf $dest $sources");
    upload_logs($dest, failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
