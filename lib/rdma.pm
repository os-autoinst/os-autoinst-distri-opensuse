# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: RDMA(Remote Direct Memory Access) related functions, mainly emulate RDMA
#
# To enable RDMA you need a RDMA card or only use emulate function in this lib
# There are two different emulate technology: rdma_rxe(RDMA over Ethernet emulation), rdma_siw(Software iWARP)
# Here we use rdma_rxe by default
#
# Maintainer: Yong Sun <yosun@suse.com>
package rdma;

use base Exporter;
use Exporter;
use 5.018;
use strict;
use warnings;
use utils;
use testapi;
use base 'opensusebasetest';
use File::Basename;
use transactional;
use package_utils;

our @EXPORT = qw(
  install_rdma_dependency
  modprobe_rdma
  link_add_rdma
  link_add_rxe
  rdma_record_info
  enable_rdma_in_nfs);

sub install_rdma_dependency {
    my @deps = qw(
      rdma-core-devel
      librdmacm-utils
      infiniband-diags
      libibverbs-utils
      kernel-default-extra
    );
    my $packages = join(' ', @deps);
    script_run('zypper --gpg-auto-import-keys ref');
    install_package($packages, trup_reboot => 1);
}

sub modprobe_rdma {
    my $rdma_type = shift || 'rdma_rxe';
    script_run("modprobe $rdma_type");
}

sub link_add_rdma {
    my ($link_name, $link_type, $network_device) = @_;
    script_run("rdma link add $link_name type $link_type netdev $network_device");
}

sub link_add_rxe {
    my $network_device = script_output("ip route | awk 'NR==1 {print \$5}'");
    link_add_rdma('rxe_link', 'rxe', $network_device);
}

sub rdma_record_info {
    record_info('ibv_devices', script_output('ibv_devices'));
    record_info('ibv_devinfo', script_output('ibv_devinfo'));
}

sub enable_rdma_in_nfs {
    # Add rdma=y and rdma-port=20049 into [nfsd] session in /etc/nfs.conf, and make sure they are the final setting with the same parameter
    script_run('sed -i \'/^\[nfsd\\]$/a rdma-port=20049\' /etc/nfs.conf');
    script_run('sed -i \'/^\[nfsd\\]$/a rdma=y\' /etc/nfs.conf');
}

1;
