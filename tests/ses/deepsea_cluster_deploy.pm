# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Deploy ceph cluster http://docserv.suse.de/documents/Storage_5/ses-deployment/single-html/
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(systemctl zypper_call);
use version_utils 'is_sle';

sub run {
    if (check_var('HOSTNAME', 'master')) {
        my $num_nodes = get_var('NODE_COUNT');
        barrier_create('salt_master_ready',      $num_nodes + 1);
        barrier_create('salt_minions_connected', $num_nodes + 1);
        zypper_call 'in openattic' if is_sle('<15');
        assert_script_run 'echo "deepsea_minions: \'*\'" > /srv/pillar/ceph/deepsea_minions.sls';
        systemctl 'start salt-master';
        systemctl 'enable salt-master';
        systemctl 'status salt-master';
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        barrier_wait {name => 'salt_master_ready', check_dead_job => 1};
        # wait until all minions are started and accept minion keys
        barrier_wait {name => 'salt_minions_connected', check_dead_job => 1};
        # before accepting the key, wait until the minions are fully started (systemd might be not reliable)
        assert_script_run "salt-run state.event pretty=False tagmatch='salt/auth' quiet=False count=$num_nodes |& tee /dev/$serialdev", 300;
        assert_script_run 'salt-key --accept-all --yes';
        # salt does not return 1 if any node will fail ping test
        assert_script_run 'for i in {1..7}; do echo "try $i" && if [[ $(salt \'*\' test.ping |& tee ping.log) = *"Not connected"* ]];
 then cat ping.log && false; else salt \'*\' test.ping && break; fi; done';
        assert_script_run "salt \'*\' cmd.run \'lsblk\' |& tee /dev/$serialdev";
        my $policy = get_var('SES_POLICY');
        # Disable tuned for SES6
        my $tuned_off = <<'EOF';
alternative_defaults:
    tuned_mgr_init: default-off
    tuned_mon_init: default-off
    tuned_osd_init: default-off
EOF
        if (is_sle('15+')) {
            script_run("echo -e '$tuned_off' >> /srv/pillar/ceph/stack/global.yml");
            record_soft_failure "bnc:#1139379 - Workaround deepsea subvolume checks. PR https://github.com/SUSE/DeepSea/pull/1701 is not merged yet!";
            assert_script_run "wget -nd -O /srv/salt/ceph/subvolume/default.sls https://raw.githubusercontent.com/SUSE/DeepSea/7cab8f2265e7afc052b9209ae1f82d3b7693de21/srv/salt/ceph/subvolume/default.sls |& tee /dev/$serialdev";
            # appy state on monitor nodes with the changed default.sls
            assert_script_run "wget -nd -O /srv/salt/_modules/subvolume.py https://raw.githubusercontent.com/SUSE/DeepSea/7cab8f2265e7afc052b9209ae1f82d3b7693de21/srv/salt/_modules/subvolume.py && salt '*' saltutil.sync_all |& tee /dev/$serialdev";
            assert_script_run "salt 'node[234]*' state.apply ceph.subvolume |& tee /dev/$serialdev";
        }
        assert_script_run 'wget ' . data_url("ses/$policy");
        assert_script_run "set -o pipefail; salt-run state.orch ceph.stage.0 |& tee /dev/$serialdev", 700;
        assert_script_run "salt-run state.orch ceph.stage.1 |& tee /dev/$serialdev",                  700;
        assert_script_run "mv $policy /srv/pillar/ceph/proposals/policy.cfg";
        # Remove openATTIC role for SES6 - it is replaced by the ceph dashboard
        if (is_sle('15+')) {
            assert_script_run "sed -i -e '/\# openATTIC/d' -e '/role-openattic/d' /srv/pillar/ceph/proposals/policy.cfg";
            # Adjust to Deepsea Drive Groups - role-storage is mandatory now (starting from M13).
            assert_script_run "echo '\n# Storage\nrole-storage/cluster/node[1234]*.sls' >> /srv/pillar/ceph/proposals/policy.cfg";
        }
        assert_script_run "salt-run state.orch ceph.stage.2 |& tee /dev/$serialdev", 1200;
        # Disable AppArmor http://docserv.suse.de/documents/SES_6/ses-admin/single-html/#admin.apparmor
        # assert_script_run "salt -I 'deepsea_minions:*' state.apply ceph.apparmor.default-disable -l debug |& tee /dev/$serialdev" if is_sle('15+');
        # See again after https://bugzilla.suse.com/show_bug.cgi?id=1130930
        if (is_sle('15+')) {
            record_soft_failure 'Workaround apparmor - bsc#1130930';
            assert_script_run "salt '*' cmd.run 'systemctl stop apparmor.service; aa-teardown' |& tee /dev/$serialdev";
        }
        script_run "cat /srv/pillar/ceph/proposals/policy.cfg |& tee /dev/$serialdev";
        assert_script_run "salt '*' pillar.items |& tee /dev/$serialdev";
        assert_script_run "salt-run state.orch ceph.stage.3 |& tee /dev/$serialdev", 1200;
        assert_script_run "salt-run state.orch ceph.stage.4 |& tee /dev/$serialdev", 1200;
        assert_script_run "ceph osd df tree|& tee /dev/$serialdev";
        assert_script_run "ceph status |& tee /dev/$serialdev";
        barrier_wait {name => 'deployment_done', check_dead_job => 1};
    }
    else {
        barrier_wait('salt_master_ready');
        # set master node as salt-master
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        # wait until all minions are started and master will continue with deployment
        barrier_wait {name => 'salt_minions_connected'};
        # all nodes have to run until master finishes cluster deployment
        barrier_wait {name => 'deployment_done'};
    }
}

sub post_fail_hook {
    select_console('log-console');
    assert_script_run "tar czf /tmp/logs-salt.tar.bz2 /var/log/salt";
    assert_script_run "tar czf /tmp/srv-pillar-ceph.tar.bz2 /srv/pillar/ceph";
    upload_logs '/tmp/logs-salt.tar.bz2',       failok => 1;
    upload_logs '/tmp/srv-pillar-ceph.tar.bz2', failok => 1;
    upload_logs '/var/log/salt/deepsea.log',    failok => 1;
    upload_logs '/var/log/zypper.log',          failok => 1;
}

sub test_flags {
    return {fatal => 1};
}

1;

