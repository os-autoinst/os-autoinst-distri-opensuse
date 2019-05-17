# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Salt stack on two machines. Here we test mainly the
#  master but minion is also present just for having more of those.
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(zypper_call systemctl);

sub run {
    select_console 'root-console';

    # Install both salt master and minion and run the master daemon
    zypper_call("in salt-master salt-minion");
    systemctl("start salt-master");
    systemctl("status salt-master");

    # Set the right address of the salt master and run the minion
    assert_script_run('sed -i -e "s/#master: salt/master: 10.0.2.101/" /etc/salt/minion');
    systemctl("start salt-minion");
    systemctl("status salt-minion");

    # before accepting the key, wait until the minion is fully started (systemd might be not reliable)
    assert_script_run('salt-run state.event tagmatch="salt/auth" quiet=True count=1', timeout => 300);
    barrier_wait 'SALT_MINIONS_READY';

    # List and accept both minions when they are ready
    assert_script_run("salt-key -L");
    assert_script_run("salt-key --accept-all -y");
    assert_script_run "salt '*' test.ping";

    # Run a command and wait for minion
    assert_script_run("salt '*' cmd.run 'touch /tmp/salt_touch'", 180);
    mutex_create 'SALT_TOUCH';

    # Install a package and wait for the minion
    assert_script_run(qq(echo "---
sysstat:
  pkg.installed" > /srv/salt/pkg.sls));
    assert_script_run(qq(echo "---
base:
  '*':
    - pkg" > /srv/salt/top.sls));
    assert_script_run("salt '*' state.highstate", 180);
    mutex_create 'SALT_STATES_PKG';

    # Create user and group and wait for the minion
    assert_script_run(qq(echo "---
salttestgroup:
  group.present

salttestuser:
  user.present:
    - fullname: Salt Test
    - shell: /usr/bin/sh
    - home: /home/salttestuser
    - groups:
      - salttestgroup" > /srv/salt/user.sls));
    assert_script_run("echo '    - user' >> /srv/salt/top.sls");
    assert_script_run("salt '*' state.highstate", 180);
    mutex_create 'SALT_STATES_USER';

    # Set sysctl key and wait for the minion
    assert_script_run(qq(echo "---
net.ipv4.ip_forward:
  sysctl.present:
    - value: 1" > /srv/salt/sysctl.sls));
    assert_script_run("echo '    - sysctl' >> /srv/salt/top.sls");
    assert_script_run("salt '*' state.highstate", 180);
    mutex_create 'SALT_STATES_SYSCTL';

    # Stop both master and minion at the end
    barrier_wait 'SALT_FINISHED';
    systemctl 'stop salt-master';
    systemctl 'stop salt-minion';
}

1;
