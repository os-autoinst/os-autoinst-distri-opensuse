# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: Base test module for all the tests modules of yast2 lan.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package yast2_lan_hostname_base;
use parent "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use YuiRestClient;

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    script_run 'iface=`ip -o addr show scope global | head -n1 | cut -d" " -f2`';
    upload_logs '/etc/sysconfig/network/ifcfg-$iface';
    upload_logs '/etc/sysconfig/network/dhcp';
}

1;
