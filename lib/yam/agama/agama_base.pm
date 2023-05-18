## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: base class for Agama tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package yam::agama::agama_base;
use base 'opensusebasetest';
use strict;
use warnings;
use distribution;
use testapi 'select_console';
use Utils::Logging 'save_and_upload_log';
#use y2_base 'save_upload_y2logs';
use network_utils qw(can_upload_logs recover_network);
 
sub save_upload_y2logs_without_investigation {
    my (%args) = @_;

    return if (get_var('NOLOGS') || get_var('Y2LOGS_UPLOADED'));
    $args{suffix} //= '';

    # Do not test/recover network if collect from installation system, as it won't work anyway with current approach
    # Do not recover network on non-qemu backend, as not implemented yet
    $args{no_ntwrk_recovery} //= (get_var('BACKEND') !~ /qemu/);

    # Try to recover network if cannot reach gw and upload logs if everything works
    if (can_upload_logs() || (!$args{no_ntwrk_recovery} && recover_network())) {
        script_run 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
        my $filename = "/tmp/y2logs$args{suffix}.tar" . get_available_compression();
        script_run "save_y2logs $filename", 180;
        upload_logs($filename, failok => 1);
    } else {    # Redirect logs content to serial
        script_run("journalctl -b --no-pager -o short-precise > /dev/$serialdev");
        script_run("dmesg > /dev/$serialdev");
        script_run("cat /var/log/YaST/y2log > /dev/$serialdev");
    }
    save_screenshot();
}

sub save_upload_y2logs {
    my ($self, %args) = @_;
    $self->save_upload_y2logs_without_investigation(%args);

    # We skip parsing yast2 logs in each installation scenario, but only if
    # test has failed or we want to explicitly identify failures
    $self->investigate_yast2_failure() unless $args{skip_logs_investigation};
}

sub post_fail_hook {
    my ($self) = @_;
    $testapi::password = 'linux';
    select_console 'root-console';
    Utils::Logging::save_and_upload_log('journalctl -u agama-auto', '/tmp/agama-auto-log.txt');
    save_upload_y2logs;
}

1;
