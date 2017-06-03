package btrfs_test;
use base 'consoletest';

use strict;
use testapi;

=head2 unpartitioned_disk_in_bash

Choose the disk without a partition table for btrfs experiments.
Defines the variable C<$disk> in a bash session.
=cut
sub set_unpartitioned_disk_in_bash {
    my $vd = 'vd';    # KVM
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        $vd = 'xvd';
    }
    elsif (check_var('VIRSH_VMM_FAMILY', 'hyperv') or check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        $vd = 'sd';
    }
    assert_script_run 'parted --script --machine -l';
    assert_script_run 'disk=${disk:-$(parted --script --machine -l |& sed -n \'s@^\(/dev/' . $vd . '[ab]\):.*unknown.*$@\1@p\')}';
    assert_script_run 'echo $disk';
}

sub cleanup_partition_table {
    assert_script_run 'wipefs --force --all $disk';
}

1;
# vim: set sw=4 et:
