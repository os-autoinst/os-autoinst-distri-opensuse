# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for HPC cluster provisioning
# Maintainer: Kernel QE <kernel-qa@suse.de>

package hpc::cluster;
use Mojo::Base 'hpcbase', -signatures;
use testapi;
use utils;

our @EXPORT = qw(
  provision_cluster
);

sub provision_cluster ($self) {
    my $config = << "EOF";
sed -i '/^DHCLIENT_SET_HOSTNAME.*/c\\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp
EOF
    assert_script_run($_) foreach (split /\n/, $config);
}

1;
