# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure and run kdump over NFS.
#
# Maintainer: QE Kernel <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use kdump_utils;
use lockapi;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');
    my $nfs_server = get_var('NFS_SERVER', 'server-node00');

    get_required_var('KDUMP_SAVEDIR');

    select_console('root-console');

    #Specific wicked workaround for SLE15 - allow connection from all hosts
    if ($role eq 'nfs_server') {
        assert_script_run("echo '/var/lib/nfs-tests/shared_nfs3 10.0.2.0/24(rw,sync,no_subtree_check,no_root_squash)' > /etc/exports");
        assert_script_run("exportfs -ra");
    }

    barrier_wait('KDUMP_WICKED_TEMP');

    if ($role eq 'nfs_client') {
        assert_script_run("mkdir -p /var/crash");
        assert_script_run("echo \"$nfs_server:/var/lib/nfs-tests/shared_nfs3 /var/crash nfs nfsvers=3,sync,nofail,x-systemd.automount 0 0\" >> /etc/fstab");
        assert_script_run("mount -a");

        configure_service(test_type => 'function', yast_interface => 'cli');
        check_function(test_type => 'function');
    }
    barrier_wait("KDUMP_MULTIMACHINE");
}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;

=head1 Description

On the B<NFS server> node the module exports C</var/lib/nfs-tests/shared_nfs3>
to the C<10.0.2.0/24> subnet with C<rw>, C<sync>, C<no_subtree_check> and
C<no_root_squash> options.

On the B<NFS client> node the module mounts the NFS share under C</var/crash>
via C</etc/fstab> using NFSv3 with C<x-systemd.automount>, then calls
C<configure_service> and C<check_function> from L<kdump_utils> to configure
kdump, trigger a kernel crash, and verify the dump files are present on the
NFS share after reboot.

=head1 Configuration

=head2 ROLE

Required. Set to C<nfs_server> or C<nfs_client> to select the node's role
in the multi-machine scenario.

=head2 KDUMP_SAVEDIR

Required. NFS path used as the kdump crash dump destination,
e.g. C<nfs://server-node00/var/lib/nfs-tests/shared_nfs3>.

=head2 NFS_SERVER

Hostname or IP of the NFS server as seen from the client.
Defaults to C<server-node00>.

=head1 Barriers

=head2 KDUMP_WICKED_TEMP

Synchronises all nodes after the NFS export is in place, working around a
wicked connection-tracking issue on SLE 15.

=head2 KDUMP_MULTIMACHINE

Final barrier; all nodes must reach it before the test is considered complete.

=cut
