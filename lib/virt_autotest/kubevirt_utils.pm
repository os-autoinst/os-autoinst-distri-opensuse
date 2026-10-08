# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Utilities for setup kubevirt plugins and commands execution
# Maintainer: Nan Zhang <nan.zhang@suse.com> qe-virt@suse.de

package virt_autotest::kubevirt_utils;

use base Exporter;
use Exporter;

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_transactional);
use bootloader_setup qw(change_grub_config);

our @EXPORT = qw(
  set_grub_timeout
  install_cni_plugins
);

sub set_grub_timeout {
    my $grub_timeout = shift // 30;

    if (is_transactional) {
        change_grub_config('=.*', '=' . $grub_timeout, 'GRUB_TIMEOUT');
        record_info('GRUB', script_output('cat /etc/default/grub'));
        assert_script_run('transactional-update grub.cfg');
    }
}

sub install_cni_plugins {
    # Setup cnv-bridge containernetworking plugin: one of the tests requires
    # a newer version of the Linux bridge CNI:
    #   https://github.com/kubevirt/kubevirt/commit/3fa7e2b67f9095d664e83eb1e13b587ab76b4950
    assert_script_run("curl -LO https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz");
    assert_script_run("curl -LO https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz.sha256");
    assert_script_run("sha256sum --check cni-plugins-linux-amd64-v1.1.1.tgz.sha256");
    assert_script_run("mkdir -p /opt/cni/bin");
    assert_script_run("tar -xOf cni-plugins-linux-amd64-v1.1.1.tgz ./bridge > /opt/cni/bin/cnv-bridge");
    assert_script_run("chmod +x /opt/cni/bin/cnv-bridge");
}

1;
