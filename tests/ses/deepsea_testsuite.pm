# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run Deepsea testsuites https://github.com/SUSE/DeepSea/tree/master/qa
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use mm_network;
use lockapi;
use utils 'systemctl';
use version_utils 'is_sle';

sub run {
    if (check_var('HOSTNAME', 'master')) {
        my $num_nodes = get_var('NODE_COUNT');
        barrier_create('salt_master_ready',      $num_nodes + 1);
        barrier_create('salt_minions_connected', $num_nodes + 1);
        systemctl 'start salt-master';
        systemctl 'enable salt-master';
        systemctl 'status salt-master';
        barrier_wait {name => 'salt_master_ready', check_dead_job => 1};
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        barrier_wait {name => 'salt_minions_connected', check_dead_job => 1};
        # give time to salt to establish connection, to accept keys of all nodes
        sleep 2;
        assert_script_run 'salt-key --accept-all --yes';
        assert_script_run 'cd /usr/lib/deepsea/qa/';
        # print system info
        assert_script_run 'uname -a';
        assert_script_run 'cat /etc/os-release';
        # test salt connection with ping poo#33016
        assert_script_run 'for i in {1..7}; do echo "try $i" && if [[ $(salt \'*\' test.ping |& tee ping.log) = *"Not connected"* ]];
 then cat ping.log && false; else salt \'*\' test.ping && break; fi; done';
        assert_script_run 'salt \'*\' cmd.run \'lsblk\'';
        # __pycache__ is deleted in testsuite and deepsea cli doe not work properly in SES6
        record_soft_failure 'bsc#1087232' if is_sle('>=15');
        my $deepsea_cli       = is_sle('>=15') ? '' : '--cli';
        my $deepsea_testsuite = get_var('DEEPSEA_TESTSUITE');
        my $deepsea_options   = get_var('DEEPSEA_OPTIONS');
        # temporary fix https://github.com/SUSE/DeepSea/pull/1417
        script_run 'sed -i \'s/MASTER_MINION=$(hostname)/MASTER_MINION=$(hostname --fqdn)/\' common/deploy.sh';
        assert_script_run "suites/basic/$deepsea_testsuite.sh $deepsea_cli $deepsea_options | grep \"test result: PASS\$\"", 4000;
    }
    else {
        barrier_wait {name => 'salt_master_ready', check_dead_job => 1};
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        barrier_wait {name => 'salt_minions_connected', check_dead_job => 1};
    }
    barrier_wait {name => 'all_tests_done', check_dead_job => 1};
}

sub post_fail_hook {
    upload_logs '/var/log/salt/deepsea.log';
    upload_logs '/var/log/zypper.log';
}

1;

