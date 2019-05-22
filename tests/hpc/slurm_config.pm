# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC cluster helpers
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use utils;

sub prepare_slurm_conf {
    # Create proper /etc/hosts and /etc/slurm.conf for each node
    my $nodes = get_required_var("CLUSTER_NODES");

    my $slurm_slave_nodes = "";
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("slurm-slave%02d", $node);
        $slurm_slave_nodes = "${slurm_slave_nodes},${node_name}";
    }
    my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=slurm-master" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=slurm-master${slurm_slave_nodes} Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=slurm-master${slurm_slave_nodes} Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
    assert_script_run($_) foreach (split /\n/, $config);
}

1;
