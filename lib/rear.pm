# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for ReaR tests

package rear;
use Mojo::Base 'opensusebasetest';

use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use version_utils qw(is_sle);
use Utils::Logging 'save_and_upload_log';

our @EXPORT = qw(
  upload_rear_logs
  upload_fs_blk_info
);

=head1 SYNOPSIS

Package with common methods and default values for testing ReaR on HA
module.

This package inherits from B<opensusebasetest> and should be used as
a class.

=cut

=head2 rear_cmd_log

 $self->rear_cmd_log();
 $self->rear_cmd_log('/path/to/log/file.log');

Sets or gets the full path to the ReaR command log.
=cut

has rear_cmd_log => '/var/log/rear-cmd.log';

=head2 upload_fs_blk_info

 $self->upload_fs_blk_info(prefix => $prefix);

Upload outputs of C<lsblk> and C<findmnt> commands. If supplied with a prefix
in the named argument B<prefix>, prepend the log file names with it.
=cut

sub upload_fs_blk_info {
    my ($self, %args) = @_;
    my $path_and_prefix = '/tmp/';
    $path_and_prefix .= $args{prefix} . '-' if ($args{prefix});

    # List of block devices
    my $lsblk_cmd = 'lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,SIZE,';
    $lsblk_cmd .= is_sle('>=16') ? 'MOUNTPOINTS' : 'MOUNTPOINT';
    save_and_upload_log($lsblk_cmd, "${path_and_prefix}lsblk.log");

    # List of filesystems
    save_and_upload_log('findmnt -a -o SOURCE,TARGET,FSTYPE -t btrfs,ext2,ext3,ext4,xfs,reiserfs,vfat', "${path_and_prefix}findmnt.log");
}

=head2 upload_rear_logs

 $self->upload_rear_logs();

Upload needed logs for debugging purposes.
=cut

sub upload_rear_logs {
    my ($self) = @_;

    # Upload config file
    upload_logs('/etc/rear/local.conf', failok => 1);

    # Record outputs of lsblk and findmnt
    $self->upload_fs_blk_info();

    # Create tarball with logfiles and upload it
    my $logfile = '/tmp/rear-recover-logs.tar.bz2';
    script_run("tar cjf $logfile /var/log/rear/* /var/lib/rear/layout/* /var/lib/rear/recovery/*");
    upload_logs($logfile, failok => 1);
    upload_logs($self->rear_cmd_log(), failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;

    return if get_var('NOLOGS');
    # Attempt to clear the current terminal session from any running script
    is_serial_terminal() ? type_string('', terminate_with => 'ETX') : send_key 'ctrl-c';
    enter_cmd 'clear';
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
