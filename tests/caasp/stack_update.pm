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
    wait_still_screen 3;
    assert_and_click 'velum-update-reboot';

    # Update all nodes - this part takes long time (~2 minutes per node)
    my @needles_array = ('velum-sorry', "velum-$n-nodes-outdated");
    assert_screen [@needles_array], 900;
    if (match_has_tag 'velum-sorry') {
        record_soft_failure('bnc#1074836 - delay caused due to Meltdown');
        # workaround for meltdown
        send_key_until_needlematch "velum-$n-nodes-outdated", 'f5', 10, 120;
    }

    # Workaround for bsc#1099015
    if (check_screen 'velum-update-admin', 0) {
        record_soft_failure 'bsc#1099015 - Update admin node still visible after reboot';
        for (1 .. 10) {
            sleep 60;
            last unless (check_screen 'velum-update-admin', 0);
        }
        die "Admin should be updated already" if check_screen('velum-update-admin', 0);
    }
    assert_and_click "velum-update-all";

    # 15 minutes per node
    my @tags = qw(velum-retry velum-bootstrap-done);
    assert_screen \@tags, $n * 900;
    if (match_has_tag 'velum-retry') {
        record_soft_failure 'bsc#000000 - Should have passed first time';
        assert_and_click 'velum-retry';
        assert_screen 'velum-bootstrap-done', $n * 900;
    }
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

# ./update.sh -s will set up repositories
sub update_setup_repos {
    record_info 'Repo', 'Add the testing repository into each node of the cluster';
    switch_to 'xterm';

    # Deregister before distribution update
    if (update_scheduled 'dup') {
        script_assert0 "ssh $admin_fqdn './update.sh -s dup' | tee /dev/$serialdev", 120;
    }

    # Add UPDATE repository
    my $repo = update_scheduled;
    script_assert0 "ssh $admin_fqdn './update.sh -s $repo' | tee /dev/$serialdev", 120;
}

# ./update.sh -n will install new package (QAM) if any
sub install_new_packages {
    record_info "NEW Package", "Check if this maintenance incident includes NEW package and if so then install it.";
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -n' | tee /dev/$serialdev", 600);
    if ($returnCode == 100) {
        # Reboot the cluster
        record_info "Installed NEW Package", "This maintenance incident includes NEW package we just installed.";
        orchestrate_velum_reboot;
        update_check_changes;
    }
    elsif ($returnCode == 0) {
        record_info 'No NEW Package', 'No NEW packages included in this maintenance incident.';
    }
    else {
        die "NEW Package installation failed";
    }
}

# ./update.sh -t will decide if it makes sense to run update_perform_update
sub is_needed {
    # Always needed for QA scenarios
    return 1 unless is_caasp('qam');

    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -t' | tee /dev/$serialdev", 120);
    if ($returnCode == 110) {
        record_info 'Skip Update', 'This maintenance incident was just one single new package';
        return 0;
    }
    else {
        record_info 'Ready to update', 'We are ready to perform the update.';
        return 1;
    }
}

# ./update.sh -i will install missing packages (QAM)
sub install_missing_packages {
    record_info "MISSING Package", "Check if this maintenance incident includes MISSING package and if so then install it.";
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -i' | tee /dev/$serialdev", 600);
    if ($returnCode == 100) {
        # Reboot the cluster
        record_info 'Installed MISSING Package', 'This maintenance incident includes MISSING package we just installed.';
        orchestrate_velum_reboot;
        update_check_changes;
    }
    elsif ($returnCode == 0) {
        record_info 'No MISSING Package', 'All packages included in this maintenance incident are pre-installed (DVD).';
    }
    else {
        die "MISSING Package installation failed";
    }
}

# ./update.sh -u will perform actual update
sub update_perform_update {
    record_info 'Update', 'Apply the update using transactional update via salt and docker';
    switch_to 'xterm';
    my $ret = script_run0("ssh $admin_fqdn './update.sh -u' | tee /dev/$serialdev", 1500);
    $ret == 100 ? orchestrate_velum_reboot : die('Update process failed');
}

sub run {
    # update.sh -s $repo
    update_setup_repos;

    if (is_caasp 'qam') {
        install_new_packages;        # update.sh -n
        install_missing_packages;    # update.sh -i
    }

    # update.sh -u
    update_perform_update if is_needed();

    # update.sh -c
    update_check_changes if update_scheduled('fake');
}

1;
