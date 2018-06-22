# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update cluster from OBS repository
#   SSH keys are already generated
#   SSH config was modified to not check identity
#   Script is not run on admin to avoid mutex hell
# Maintainer: Martin Kravec <mkravec@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use caasp;
use version_utils 'is_caasp';

# Orchestrate the reboot via Velum
sub orchestrate_velum_reboot {
    record_info 'Reboot', 'Orchestrate the reboot via Velum';
    switch_to 'velum';

    my $n = get_required_var('STACK_NODES');
    assert_screen "velum-$n-nodes-outdated", 60;
    if (check_screen "velum-update-all", 0) {
        record_soft_failure 'bnc#1085677 - Should not update nodes before admin';
    }

    # Update admin node (~160s for admin reboot)
    assert_and_click 'velum-update-admin';
    assert_and_click 'velum-update-reboot';

    # Update all nodes - this part takes long time (~2 minutes per node)
    my @needles_array = ('velum-sorry', "velum-$n-nodes-outdated");
    assert_screen [@needles_array], 300;
    if (match_has_tag 'velum-sorry') {
        record_soft_failure('bnc#1074836 - delay caused due to Meltdown');
        # workaround for meltdown
        send_key_until_needlematch "velum-$n-nodes-outdated", 'f5', 10, 120;
    }

    if (check_screen 'velum-update-admin', 0) {
        record_soft_failure 'bsc#1099015 - Update admin node still visible after reboot';
        sleep 60;
    }
    die "Admin should be updated already" if check_screen('velum-update-admin', 0);
    assert_and_click "velum-update-all";

    # 5 minutes per node
    assert_screen 'velum-bootstrap-done', $n * 300;
    die "Nodes should be updated already" if check_screen "velum-0-nodes-outdated", 0;
}

# ./update.sh -c will check update was really applied
sub update_check_changes {
    switch_to 'xterm';

    # Kubernetes checks
    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl cluster-info > cluster.after_update";
    if (script_run "diff -Nur cluster.before_update cluster.after_update") {
        record_info "Old kubeconfig cannot see DEX - bsc#1081337";
        switch_to 'velum';
        download_kubeconfig;
    }
    my $nodes_count = get_required_var("STACK_NODES");
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";

    # QA: fake repo with pre-defined values (hardcoded)
    unless (is_caasp 'qam') {
        script_assert0 "ssh $admin_fqdn './update.sh -c' | tee /dev/$serialdev", 60;
    }
}

# ./update.sh -u will set up repositories
sub update_setup_repo {
    record_info 'Repo', 'Add the testing repository into each node of the cluster';
    switch_to 'xterm';

    # Add UPDATE repository
    my $repo = update_scheduled;
    script_assert0 "ssh $admin_fqdn './update.sh -s $repo' | tee /dev/$serialdev", 120;
}

# ./update.sh -u will install missing packages (QAM)
sub update_install_packages {
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -i' | tee /dev/$serialdev", 600);
    if ($returnCode == 100) {
        record_info 'Prepare', 'Install packages that are not part of the DVD but they are part of this incident';
        # Reboot the cluster
        orchestrate_velum_reboot;
        update_check_changes;
    }
    elsif ($returnCode == 0) {
        record_info 'Skip Prepare', 'All packages included in this maintenance incident are pre-installed (DVD).';
    }
    else {
        die "Package installation failed";
    }
}

# ./update.sh -u will perform actual update
sub update_perform_update {
    record_info 'Update', 'Apply the update using transactional update via salt and docker';
    script_assert0("ssh $admin_fqdn './update.sh -u' | tee /dev/$serialdev", 1200);
    orchestrate_velum_reboot;
}

sub run {
    # update.sh -s $repo
    update_setup_repo;

    # update.sh -i
    update_install_packages if is_caasp('qam');

    # update.sh -u
    update_perform_update;

    # update.sh -c
    update_check_changes;
}

1;
