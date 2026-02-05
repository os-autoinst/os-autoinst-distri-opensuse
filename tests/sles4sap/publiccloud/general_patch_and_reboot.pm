# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Refresh repositories, apply patches and reboot
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/general_patch_and_reboot.pm - Refresh repositories, apply patches and reboot

=head1 DESCRIPTION

Refreshes repositories, applies all patches, and reboots the system.
This is targeted at instances matching 'vmhana'.

Its primary tasks are:

- Connect to each 'vmhana' instance.
- Kill PackageKit to release locks.
- Refresh repositories (`zypper ref`).
- Fully patch the system.
- Reboot the instance.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_REBOOT_TIMEOUT>

Timeout for the system reboot. Defaults to 600.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::publiccloud_basetest';
use testapi;
use registration;
use utils;
use publiccloud::ssh_interactive qw(select_host_console);
use publiccloud::utils qw(zypper_call_remote is_azure);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);
    select_host_console();    # select console on the host, not the PC instance

    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        record_info("$instance");

        my $remote = '-o ControlMaster=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ' . $instance->username . '@' . $instance->public_ip;

        my $cmd_time = time();
        my $ref_timeout = is_azure ? 3600 : 240;
        zypper_call_remote($instance, cmd => " --gpg-auto-import-keys ref", timeout => $ref_timeout, retry => 6, delay => 60);
        record_info('zypper ref time', 'The command zypper -n ref took ' . (time() - $cmd_time) . ' seconds.');
        record_soft_failure('bsc#1195382 - Considerable decrease of zypper performance and increase of registration times') if ((time() - $cmd_time) > 240);

        ssh_fully_patch_system($remote);

        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    }
}

1;
