# Copyright (C) 2015 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

use strict;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    my $self = shift;

    my $children = get_children();
    # there should be only one child - the control job
    my $control_id = (keys %$children)[0];

    unless ($control_id) {
        print "Control node does not exist, nothing to do\n";
        return;
    }

    my $control_settings = get_job_info($control_id)->{settings};

    # copy the network configuration from control node
    for (my $i = 0; $i < 10; $i++) {
        set_var("NETWORK$i", $control_settings->{"NETWORK$i"}) if $control_settings->{"NETWORK$i"};
    }

    type_string("rcnetwork stop\n");
    configure_hostname(get_var('SLENKINS_NODE'));

    mutex_lock('dhcp', $control_id);
    mutex_unlock('dhcp');
    configure_dhcp();

    if ($control_settings->{"SUPPORT_SERVER_ROLES"} !~ /\bdns\b/) {
        # dns on control node (supportserver) is not configured
        # -> use external dns
        configure_static_dns(get_host_resolv_conf());
    }
    # else use the supportserver dns configured via dhcp

    my $conf_script = "zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites\n";

    if (get_var('SLENKINS_INSTALL')) {
        $conf_script .= "zypper -n --no-gpg-checks in " . join(' ', split(/[\s,]+/, get_var('SLENKINS_INSTALL'))) . "\n";
    }

    $conf_script .= "
        useradd -m testuser
        mkdir /root/.ssh
        mkdir /home/testuser/.ssh
        curl -f -v " . autoinst_url . "/data/slenkins/ssh/authorized_keys > /root/.ssh/authorized_keys
        cp /root/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys
        chown -R testuser /home/testuser/.ssh
        chmod 600 /root/.ssh/*
        chmod 700 /root/.ssh
        chmod 600 /home/testuser/.ssh/*
        chmod 700 /home/testuser/.ssh
        rcSuSEfirewall2 stop
        rcsshd restart
    ";
    script_output($conf_script, 100);

    type_string("cat /var/log/messages >/dev/$serialdev\n");
    # send messages logged during the testsuite runtime to serial
    type_string("journalctl -f >/dev/$serialdev\n");

    mutex_create(get_var('SLENKINS_NODE'));

    wait_for_children;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
