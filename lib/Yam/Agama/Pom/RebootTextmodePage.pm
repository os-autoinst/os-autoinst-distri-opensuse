# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen for textmode display.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootTextmodePage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {}, $class;
}

sub reboot {
    my ($self) = @_;
    enter_cmd 'reboot';
}

sub expect_is_shown {
    my ($self, %args) = @_;
    my $timeout = $args{timeout};
    my $errors_in_log;

    while (1) {
        # agama log error
        script_run('journalctl -u agama > /tmp/journal.log');
        script_run("cat /tmp/journal.log");
        # my $errors_in_log = script_output "grep 'ERROR -- :' /tmp/journal.log";
        #if ($errors_in_log) {
        #    record_info('Found errors in agama journal',
        #        "Error is $errors_in_log please check it",
        #        result => 'fail');
        #    die "agama failed with ($errors_in_log), please check the agama log.";
        #}
        my $agama_auto_finished = script_run("grep 'agama-auto.service: Deactivated successfully' /tmp/journal.log");
        if (!$agama_auto_finished) {
            record_info('Install finished', "agama-auto Deactivated successfully", result => 'pass');
            return;
        }

        # agama-auto service check
        script_run('journalctl -u agama-auto > /tmp/journal_auto.log');
        script_run('cat /tmp/journal_auto.log');

        $errors_in_log = script_output "grep 'agama-auto service: Main process exited' /tmp/journal_auto.log | grep FAILURE";
        if ($errors_in_log) {
            record_info('Found errors in agama auto journal',
                "Error is $errors_in_log please check it",
                result => 'fail');
            die "agama failed with ($errors_in_log), please check the agama log.";
        }
        # wait the installation to be finished.
        my $yast_install_finished = script_run("grep 'Error output: Installation finished. No error reported.' /var/log/YaST2/y2log");
        if ($yast_install_finished) {
            record_info('Install finished', "$yast_install_finished", result => 'pass');
            return;
        }

        die "timeout ($timeout) hit on during installation" if $timeout <= 0;
        $timeout -= 30;
        diag("left total timeout: $timeout");
        next;
    }
}

1;
