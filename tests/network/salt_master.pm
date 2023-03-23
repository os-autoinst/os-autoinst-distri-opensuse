# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: salt-master salt-minion sysstat
# Summary: Test Salt stack on two machines. Here we test mainly the
#  master but minion is also present just for having more of those.
# - Install salt-master
#   - Enable debug
#   - Enable, start and check salt-master service
#   - Enable event logging
# - Install salt-minion
#   - Set hostname
#   - Enable debug
#   - Enable, start and check salt-minion service
# - Create mutex lock for tests
# - List and accept both minions when they are ready
# - Inform minion that keys were accepted
# - Try to ping both minions
# - Run a command and wait for minion
# - Fetch top.sls from datadir
# - Install a package and wait for the minion
# - Create user and group and wait for the minion
# - Set sysctl key and wait for the minion
# - Stop both master and minion at the end
# Maintainer: QE Core <qe-core@suse.de>

use base "saltbase";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils qw(script_retry zypper_call);

sub run {
    barrier_create('SALT_MINIONS_READY', 2);
    barrier_create('SALT_FINISHED', 2);
    mutex_create 'barrier_setup_done';
    my $self = shift;
    select_serial_terminal;

    # Install, configure and start the salt master
    $self->master_prepare();

    # Install, configure and start the salt minion
    $self->minion_prepare();

    # Both machines are ready
    barrier_wait 'SALT_MINIONS_READY';

    # List and accept both minions when they are ready
    script_retry('salt-key -L -l unaccepted | grep "master"', delay => 15, retry => 15);
    script_retry('salt-key -L -l unaccepted | grep "minion"', delay => 15, retry => 15);
    assert_script_run('salt-run state.event tagmatch="salt/auth" count=1', timeout => 300);
    assert_script_run("(sleep 5 && salt-key -A -y ) & salt-run state.event tagmatch='salt/minion/*/start' count=2 && salt '*' test.ping", timeout => 360);

    # Inform minion that keys were accepted
    mutex_create 'SALT_KEYS_ACCEPTED';
    assert_script_run('salt-call test.ping', timeout => 360);

    # Try to ping both minions
    record_info 'test.ping';
    assert_script_run("salt --state-output=terse -t 360 '*' test.ping", timeout => 360);

    # Run a command and wait for minion
    record_info 'cmd.run touch';
    assert_script_run("salt --state-output=terse -t 300 '*' cmd.run 'touch /tmp/salt_touch'", 300);
    mutex_create 'SALT_TOUCH';

    # Add top.sls
    assert_script_run("curl -s " . data_url('salt/top.sls') . " -o /srv/salt/top.sls");

    # Install a package and wait for the minion
    record_info 'pkg.installed';
    zypper_call 'in -fy --download-only sysstat';
    assert_script_run "mv `find /var/cache/zypp/packages/ | grep sysstat | head -n1` /srv/salt/sysstat.rpm";
    assert_script_run("curl -s " . data_url('salt/pkg.sls') . " -o /srv/salt/pkg.sls");
    assert_script_run("echo '    - pkg' >> /srv/salt/top.sls");
    assert_script_run("salt --state-output=terse -t 300 '*' state.highstate", 300);
    assert_script_run("sed -i '/- pkg/d' /srv/salt/top.sls");
    mutex_create 'SALT_STATES_PKG';

    # Create user and group and wait for the minion
    record_info "group.present user.present";
    assert_script_run("curl -s " . data_url('salt/user.sls') . " -o /srv/salt/user.sls");
    assert_script_run("echo '    - user' >> /srv/salt/top.sls");
    assert_script_run("salt --state-output=terse -t 300 '*' state.highstate", 300);
    mutex_create 'SALT_STATES_USER';

    # Set sysctl key and wait for the minion
    record_info "sysctl.present";
    assert_script_run("curl -s " . data_url('salt/sysctl.sls') . " -o /srv/salt/sysctl.sls");
    assert_script_run("echo '    - sysctl' >> /srv/salt/top.sls");
    assert_script_run("salt --state-output=terse -t 300 '*' state.highstate", 300);
    mutex_create 'SALT_STATES_SYSCTL';

    barrier_wait 'SALT_FINISHED';
}

1;
