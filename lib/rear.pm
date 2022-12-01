# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for ReaR tests

package rear;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use Utils::Logging 'save_and_upload_log';

our @EXPORT = qw(
  upload_rear_logs
);

=head1 SYNOPSIS

Package with common methods and default values for testing ReaR on HA
module.

This package inherits from B<opensusebasetest> and should be used as
a class.

=cut

=head2 upload_rear_logs

 $self->upload_rear_logs();

Upload needed logs for debugging purposes.
=cut

sub upload_rear_logs {
    my ($self) = @_;

    # Upload config file
    upload_logs('/etc/rear/local.conf', failok => 1);

    # List of block devices
    save_and_upload_log('lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,SIZE,MOUNTPOINT', '/tmp/lsblk.log');

    # Create tarball with logfiles and upload it
    my $logfile = '/tmp/rear-recover-logs.tar.bz2';
    script_run("tar cjf $logfile /var/log/rear/rear-*.log /var/lib/rear/layout/* /var/lib/rear/recovery/*");
    upload_logs("$logfile", failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;

    # We need to be sure that *ALL* consoles are closed, are SUPER:post_fail_hook
    # does not support virtio/serial console yet
    reset_consoles;
    select_console('root-console');

    # Upload the logs
    $self->upload_rear_logs;

    # Execute the common part
    $self->SUPER::post_fail_hook unless check_var('LIVETEST', 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
