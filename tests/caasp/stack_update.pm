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
# Maintainer: Martin Kravec <mkravec@suse.com>, Georgios Gkioulis <ggkioulis@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use warnings;
use testapi;
use caasp;
use utils 'systemctl';
use version_utils 'is_caasp';

# Orchestrate the reboot via Velum
sub orchestrate_velum_reboot {
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
    assert_screen [@needles_array], 600;
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
        record_soft_failure 'bsc#000000 - Update failed once, retrying';
        assert_and_click 'velum-retry';

        assert_screen \@tags, $n * 900;
        die 'Update failed twice' unless match_has_tag('velum-bootstrap-done');
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

    # QA: TestUpdate repo with pre-defined values (hardcoded)
    unless (is_caasp 'qam') {
        script_assert0 "ssh $admin_fqdn './update.sh -c' | tee /dev/$serialdev", 60;
    }
}

# ./update.sh -s will set up repositories
sub update_setup_repos {
    record_info 'Setup', 'Add the testing repository into each node of the cluster';
    switch_to 'xterm';

    # Add UPDATE repository
    my $repo = update_scheduled;
    script_assert0 "ssh $admin_fqdn './update.sh -s $repo' | tee /dev/$serialdev", 120;
}

# ./update.sh -n will install new package (QAM) if any
sub install_new_packages {
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -n' | tee /dev/$serialdev", 600);
    if ($returnCode == 100) {
        record_info 'Installed new', 'Incident package not installed & available only from UPDATE repo';
        orchestrate_velum_reboot;
        update_check_changes;
    } elsif ($returnCode != 0) {
        die 'NEW package installation failed';
    }
}

# ./update.sh -q will decide if it makes sense to run update_perform_update
sub update_available {
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -q' | tee /dev/$serialdev", 120);
    if ($returnCode == 110) {
        record_info 'Update skipped', 'All incident packages existed only in UPDATE repo';
        return 0;
    } elsif ($returnCode == 0) {
        return 1;
    }
    die './update.sh -q returned unexpected exit code';
}

# ./update.sh -i will install missing packages (QAM)
sub install_missing_packages {
    my $returnCode = script_run0("ssh $admin_fqdn './update.sh -i' | tee /dev/$serialdev", 600);
    if ($returnCode == 100) {
        record_info 'Installed missing', 'Incident package not installed & available from OS repo';
        orchestrate_velum_reboot;
        update_check_changes;
    }
    elsif ($returnCode != 0) {
        die 'MISSING package installation failed';
    }
}

# ./update.sh -u will perform actual update
sub update_perform_update {
    record_info 'Update', 'Apply the update using transactional update via salt and docker';
    switch_to 'xterm';
    my $ret = script_run0("ssh $admin_fqdn './update.sh -u' | tee /dev/$serialdev", 1500);
    $ret == 100 ? orchestrate_velum_reboot : die('Update process failed');
}

# bug#1121797 - Nodes change IP address after v3->v4 migration (feature)
sub setup_static_dhcp {
    switch_to 'xterm';
    become_root;
    assert_script_run q#arp -n | awk '/52:54:00/ {printf "host h%s {\n  hardware ethernet %s;\n  fixed-address %s;\n}\n", ++h, $3, $1}' >> /etc/dhcpd.conf#;
    systemctl 'restart dhcpd';
    type_string "exit\n";
}

# Migration from last GM to current build
sub perform_migration {
    switch_to 'xterm';
    my $build = get_required_var 'BUILD';
    salt 'cmd.run zypper mr -d -l';
    salt "cmd.run echo 'url: http://all-$build.proxy.scc.suse.de' > /etc/SUSEConnect";
    salt 'cmd.run systemctl disable --now transactional-update.timer';
    salt 'cmd.run transactional-update salt migration -n', timeout => 1500;
    salt 'saltutil.refresh_grains';
    orchestrate_velum_reboot;
}

# Fake update - set grains and reboot
sub perform_fake_update {
    switch_to 'xterm';
    salt 'grains.setval tx_update_reboot_needed True';
    salt 'saltutil.refresh_grains';
    orchestrate_velum_reboot;
}

sub run {
    if (is_caasp 'qam') {    # Use QAM Incident repository
        update_setup_repos;
        install_new_packages;
        install_missing_packages;
        update_perform_update if update_available();
    } elsif (update_scheduled 'migration') {    # Use scc proxy repositories
        setup_static_dhcp;
        perform_migration;
    } elsif (update_scheduled 'test') {         # Use TestUpdate repository
        update_setup_repos;
        update_perform_update;
        update_check_changes;
    } elsif (update_scheduled 'fake') {         # No repository - hacking grains
        perform_fake_update;
    } else {
        die 'Update module scheduled without actual update';
    }
}

1;
