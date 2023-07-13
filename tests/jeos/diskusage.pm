# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check disk usage on JeOS
# 1) Check btrfs data
# 2) Check rootfs size
# Maintainer: Martin Loviska <mloviska@suse.com>

use Mojo::Base qw(opensusebasetest);
use testapi;
use Utils::Architectures qw(is_s390x);

sub run {
    select_console 'root-console';
    # spit out only the part of the btrfs filesystem size we're interested in
    #  *-b|--raw* raw numbers in bytes, without the B suffix
    script_run "echo btrfs-data=\$(btrfs filesystem df -b / | grep Data | sed -n -e 's/^.*used=//p') | tee -a /dev/$serialdev", 0;
    my $datasize = wait_serial('btrfs-data=\d+\S+') || die "failed to get btrfs-data size";
    $datasize = substr $datasize, 11;
    chomp($datasize);

    my $btrfs_maxdatasize = get_required_var('BTRFS_MAXDATASIZE');
    record_info('Data size', $datasize . 'B', result => ($datasize < $btrfs_maxdatasize) ? 'ok' : 'fail');
    die "Data used by JeOS ($datasize) exceeded expected OS installation size ($btrfs_maxdatasize)" if $datasize > $btrfs_maxdatasize;

    # check and evaluate size of rootfs partition
    # Disk space is shown in 1K blocks by default, unless the environment variable POSIXLY_CORRECT is set, in which case 512-byte blocks are used.
    if (script_run('printenv POSIXLY_CORRECT') == 0) {
        assert_script_run('unset POSIXLY_CORRECT');
    }
    my $rootfs_size = script_output q[df --output=size / | awk 'END{print}'];
    chomp($rootfs_size);
    # value estimated by tester in kiB, no hard data reference found
    my $max_rootfs = is_s390x ? 34246208 : 26214400;
    record_info('Rootfs size', $rootfs_size . 'kiB', result => ($rootfs_size < $max_rootfs) ? 'ok' : 'fail');
    die "Rootfs by JeOS exceededs expected OS installation size (25GB)" if $rootfs_size > $max_rootfs;
}

1;
