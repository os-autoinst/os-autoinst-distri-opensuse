# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: yast2-network
# Summary: Base test module for all the tests modules of yast2 lan.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

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
