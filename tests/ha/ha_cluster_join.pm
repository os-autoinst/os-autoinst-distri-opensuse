# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add HA tests
#    - boot ha_support_server with dhcp/dns/ntp/iscsi services
#    - configure ntp/iscsi/watchdog on nodes
#    - create/join cluster using ha_cluster_init/join
#    - create shared OCFS2 and check that it's really shared
#    - check cluster status using crm_mon
#    - fence a node and check that it's really fenced
#    - grep /var/log to find segfaults at the end
# G-Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self = shift;
    barrier_wait("CLUSTER_INITIALIZED_" . $self->cluster_name);
    script_run "ping -c1 " . get_var("HACLUSTERJOIN");
    type_string "ha-cluster-join -yc " . get_var("HACLUSTERJOIN") . "\n";
    assert_screen "ha-cluster-join-password";
    type_password;
    send_key("ret", 1);
    wait_still_screen;
    script_run "crm_mon -1";
    save_screenshot;
    barrier_wait("NODE2_JOINED_" . $self->cluster_name);
}

sub test_flags {
    return {fatal => 1};
}

1;
