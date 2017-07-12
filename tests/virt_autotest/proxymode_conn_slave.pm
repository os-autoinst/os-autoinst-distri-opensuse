# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: proxymode_conn_slave: Connect physical machine through proxy machine.
# Maintainer: John <xgwang@suse.com>

use strict;
use warnings;
use testapi;
use base "proxymode";

sub run {
    my $self         = shift;
    my $ipmi_machine = get_var("IPMI_HOSTNAME");
    die "There is no ipmi ip address defined variable IPMI_HOSTNAME" unless $ipmi_machine;
    $self->connect_slave($ipmi_machine);
    $self->restart_host($ipmi_machine);
    assert_screen "proxy_virttest-pxe", 600;
    send_key 'ret';
    $self->check_prompt_for_boot();
}

sub test_flags {
    return {fatal => 1};
}

1;
