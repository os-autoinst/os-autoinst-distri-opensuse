# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for all nodes which are allowed to upgrade or update before.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $cluster_name = get_cluster_name;
    my @word = (get_required_var('UPDATE_TYPE') eq "update") ? ("Update", "updating", "UPDATED") : ("Upgrade", "upgrading", "UPGRADED");
    record_info("$word[0] node 1", "$word[0] has started for node 1") if is_node(1);

    if (is_node(2)) {
        record_info("Waiting node 1", "Node 1 is $word[1]");
        barrier_wait("NODE_$word[2]_${cluster_name}_NODE1");
        record_info("$word[0] node 2", "$word[0] has started for node 2");
    }

    # This module is always intended to run right before `migration/version_switch_upgrade_target`
    # or `ha/cluster_state_mgmt`. The former would call `reset_consoles` on non pvm backends (spvm or
    # pvm_hmc) which would remove the console associated to the serial terminal without actually
    # closing the session in the terminal. As `ha/cluster_state_mgmt` calls
    # `serial_terminal::select_serial_terminal()` as its first step, if there is no active console
    # connected to the serial terminal, but there is an open session there, it can lead to
    # unexpected failures. As a workaround, we close the session in the serial terminal here and
    # reset the consoles in all nodes. This way, `select_serial_terminal()` will be able to re-activate
    # it and start a session when called later.
    select_serial_terminal;
    enter_cmd 'exit';
    reset_consoles;
}

1;
