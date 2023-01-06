# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: nfs-client
# Summary: Validate nfs share is mounted after is enabled in AutoYaST installation.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'basetest';
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub check_nfs_server {
    my $data = shift;
    my $expected = "$data->{remote_dir} *";
    record_info('showmount', 'Check export list for server');
    my $actual = script_output("showmount -e --no-headers $data->{server}");
    assert_equals($expected, $actual);
}

sub validate_services {
    my $data = shift;
    for my $service (@{$data->{services}}) {
        assert_script_run("systemctl status --no-pager $service.service",
            sub { m/Active: $data->{services_status}/ });
    }
}

sub validate_mount_point {
    my $data = shift;
    my $expected =
      qr/$data->{server}:$data->{remote_dir}\s+$data->{mount}\s+$data->{fs_type}\s+defaults\s+0\s+0/;
    record_info('fstab', 'Check /etc/fstab');
    my $actual = script_output("grep $data->{server}:$data->{remote_dir} /etc/fstab");
    assert_matches($expected, $actual);

    record_info('mount', 'Check mount point');
    assert_script_run("mount -l | grep $data->{fs_type}");

    record_info('ls', "Check mount point is not empty");
    assert_script_run("[ \"$(ls $data->{mount})\" ]");
}

sub run {
    my $test_data = get_test_suite_data();
    check_nfs_server($test_data);
    validate_services($test_data);
    validate_mount_point($test_data);
}

1;
