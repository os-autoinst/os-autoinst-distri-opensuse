# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot cluster if update test isn't scheduled
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use caasp qw(script_retry unpause);

sub run {
    switch_to 'xterm';
    my $admin = 'admin.openqa.test';

    record_info 'Admin reboot',       'Test admin node reboot';
    script_run "ssh $admin 'reboot'", 0;
    # Wait until admin node powers off
    script_retry "ping -c1 -W1 $admin", expect => 1, retry => 3, delay => 10;
    # Wait until velum is reachable again
    script_retry "curl -kLI -m5 $admin | grep _velum_session";

    record_info 'Cluster reboot', 'Test cluster reboot';
    assert_script_run "ssh $admin './update.sh -r' | tee /dev/$serialdev | grep EXIT_OK";
    # Wait until cluster powers off
    script_retry 'kubectl get nodes', expect => 1, retry => 3, delay => 10;
    # Wait until kubernetes is reachable again
    script_retry 'kubectl get nodes';

    # Run basic kubernetes tests
    my $nodes_count = get_required_var("STACK_NODES");
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";

    switch_to 'velum';
    unpause 'REBOOT_FINISHED';
}

1;
