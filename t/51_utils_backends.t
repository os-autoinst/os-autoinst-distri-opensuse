use strict;
use warnings;
use Test::More;
use Test::Warnings;
use testapi;
use Utils::Backends;

## Test backend capability helpers.

# The scenarios below mirror backend::qemu::can_handle() and
# backend::svirt::can_handle() in os-autoinst, the only two backends
# implementing snapshot support. Every other backend inherits the
# backend::baseclass implementation, which always refuses.
sub with_vars {
    my (%vars) = @_;
    %bmwqemu::vars = %vars;
}

subtest '[has_snapshots] qemu supports snapshots regardless of architecture' => sub {
    for my $arch (qw(x86_64 s390x ppc64le aarch64)) {
        with_vars(BACKEND => 'qemu', ARCH => $arch);
        ok has_snapshots, "qemu on $arch supports snapshots";
    }
};

subtest '[has_snapshots] QEMU_DISABLE_SNAPSHOTS turns snapshots off' => sub {
    with_vars(BACKEND => 'qemu', ARCH => 'x86_64', QEMU_DISABLE_SNAPSHOTS => 1);
    ok !has_snapshots, 'snapshots disabled by QEMU_DISABLE_SNAPSHOTS';
};

subtest '[has_snapshots] NVMe drives cannot be migrated' => sub {
    with_vars(BACKEND => 'qemu', HDDMODEL => 'nvme', NUMDISKS => 1);
    ok !has_snapshots, 'HDDMODEL=nvme has no snapshots';
    with_vars(BACKEND => 'qemu', HDDMODEL_2 => 'nvme', NUMDISKS => 2);
    ok !has_snapshots, 'HDDMODEL_2=nvme has no snapshots';
    with_vars(BACKEND => 'qemu', HDDMODEL => 'virtio-blk', NUMDISKS => 1);
    ok has_snapshots, 'a non-NVMe HDDMODEL keeps snapshots';
};

subtest '[has_snapshots] svirt depends on the VMM family' => sub {
    for my $family (qw(kvm hyperv vmware)) {
        with_vars(BACKEND => 'svirt', VIRSH_VMM_FAMILY => $family);
        ok has_snapshots, "svirt with VIRSH_VMM_FAMILY=$family supports snapshots";
    }
    with_vars(BACKEND => 'svirt', VIRSH_VMM_FAMILY => 'xen');
    ok !has_snapshots, 'svirt with VIRSH_VMM_FAMILY=xen has no snapshots';
};

subtest '[has_snapshots] s390x zKVM leaves VIRSH_VMM_FAMILY unset' => sub {
    # poo#204801: the svirt backend reads VIRSH_VMM_FAMILY undefaulted while
    # consoles/sshVirtsh.pm defaults it to 'kvm'. Defaulting it here too would
    # wrongly report snapshot support and make these jobs die on
    # always_rollback.
    with_vars(BACKEND => 'svirt', ARCH => 's390x', S390_ZKVM => 1);
    ok !has_snapshots, 'svirt on s390x zKVM has no snapshots';
};

subtest '[has_snapshots] backends without snapshot support' => sub {
    for my $backend (qw(ipmi spvm pvm_hmc s390x generalhw)) {
        with_vars(BACKEND => $backend);
        ok !has_snapshots, "$backend has no snapshots";
    }
};

done_testing;
