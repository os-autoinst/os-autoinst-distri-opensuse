# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: open-iscsi xfsprogs
# Summary: Provision a LUN on the QNAP, log in to it over iSCSI and run filesystem I/O
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Kernel::multimachine_topology qw(get_node_by_role get_node_interface);
use Kernel::storage_qnap qw(create_iscsi_target create_iscsi_lun map_iscsi_lun unmap_iscsi_lun remove_iscsi_lun remove_iscsi_target);
use package_utils 'install_package';
use Utils::Systemd 'systemctl';
use iscsi qw(iscsi_discovery iscsi_login iscsi_logout);

# TODO (https://progress.opensuse.org/issues/208635):
# - test 1: the login survives a reboot (node.startup=automatic, fstab entry with _netdev)
# - test 2: several filesystems on the LUN (xfs, ext4, btrfs)
# - test 3: CHAP authentication (one-way, then mutual)

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $qnap = get_node_by_role('iscsi_target');
    my $host = $qnap->{hostname};
    my $portal = get_node_interface($qnap, 0)->{ipv4};

    my $target = $self->{target} = create_iscsi_target(host => $host, name => 'openqa', interface => 'eth1');
    my $lun = $self->{lun} = create_iscsi_lun(host => $host, name => 'openqa_lun0', size_gb => 10);
    map_iscsi_lun(host => $host, target => $target->{index}, lun => $lun);
    my $iqn = $target->{iqn};

    install_package('open-iscsi', trup_apply => 1);
    systemctl('enable --now iscsid');
    iscsi_discovery($portal);
    iscsi_login($iqn, $portal);

    my $dev = "/dev/disk/by-path/ip-$portal:3260-iscsi-$iqn-lun-0";
    assert_script_run("udevadm settle && test -b $dev");

    assert_script_run("mkfs.xfs -f $dev");
    assert_script_run("mkdir -p /mnt/iscsi && mount $dev /mnt/iscsi");
    assert_script_run('dd if=/dev/urandom of=/mnt/iscsi/data bs=1M count=512 conv=fsync');
    assert_script_run('umount /mnt/iscsi');

    iscsi_logout($iqn, $portal);
    $self->remove_qnap_storage;
}

sub remove_qnap_storage {
    my ($self) = @_;
    my $host = get_node_by_role('iscsi_target')->{hostname};
    my ($target, $lun) = delete @$self{qw(target lun)};
    if (defined $lun) {
        unmap_iscsi_lun(host => $host, target => $target->{index}, lun => $lun);
        remove_iscsi_lun(host => $host, index => $lun);
    }
    remove_iscsi_target(host => $host, index => $target->{index}) if $target;
}

sub post_fail_hook {
    my ($self) = @_;
    script_run('iscsiadm -m node --logoutall=all');
    eval { $self->remove_qnap_storage };
    record_info('QNAP cleanup', $@, result => 'fail') if $@;
}

# Not fatal, so that kernel/san_network_cleanup runs after a failure.
sub test_flags {
    return {fatal => 0};
}

1;

=head1 Description

Creates an iSCSI target and a LUN on the node with C<role: iscsi_target>
from the C<multimachine_topology> test data, logs in to it, makes an XFS
filesystem on the LUN and writes data to it. Then it logs out and
removes the LUN and the target.

The target node needs C<hostname> (QNAP management) and C<ipv4> on its
first interface (iSCSI portal). See C<Kernel::storage_qnap> for the job
settings with the QNAP credentials.

=cut
