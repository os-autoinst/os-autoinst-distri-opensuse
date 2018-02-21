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
use testapi;
use mm_network;
use lockapi;
use utils qw(zypper_call systemctl);

sub run {
    if (check_var('NODE_HOSTNAME', 'master')) {
        my $num_nodes = get_var('NODE_COUNT');
        barrier_create('salt_master_ready',      $num_nodes + 1);
        barrier_create('salt_minions_connected', $num_nodes + 1);
        zypper_call('in deepsea-qa');
        systemctl 'start salt-master';
        systemctl 'enable salt-master';
        systemctl 'status salt-master';
        barrier_wait {name => 'salt_master_ready', check_dead_job => 1};
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        assert_script_run 'sed -i \'s/#ipv6: False/ipv6: False/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        barrier_wait {name => 'salt_minions_connected', check_dead_job => 1};
        assert_script_run 'salt-key --accept-all --yes';
        assert_script_run 'salt \'*\' cmd.run \'lsblk\'';
        my $deepsea_testsuite = get_var('DEEPSEA_TESTSUITE');
        assert_script_run 'cd /usr/lib/deepsea/qa/';
        record_info 'fix', 'https://github.com/SUSE/DeepSea/pull/939 will be present in new deepsea-qa package';
        assert_script_run 'sed -i \'s/head -1$/sort | head -1/\' common/helper.sh';
        assert_script_run 'uname -a';
        assert_script_run 'cat /etc/os-release';
        assert_script_run 'rpm -q deepsea-qa';
        assert_script_run "suites/basic/$deepsea_testsuite.sh | tee /dev/tty /dev/$serialdev | grep ^OK\$", 1500;
    }
    else {
        zypper_call('in -y salt-minion');
        barrier_wait {name => 'salt_master_ready', check_dead_job => 1};
        assert_script_run 'sed -i \'s/#master: salt/master: master/\' /etc/salt/minion';
        systemctl 'start salt-minion';
        systemctl 'enable salt-minion';
        systemctl 'status salt-minion';
        barrier_wait {name => 'salt_minions_connected', check_dead_job => 1};
    }
    barrier_wait {name => 'all_tests_done', check_dead_job => 1};
}

1;

# vim: set sw=4 et:
