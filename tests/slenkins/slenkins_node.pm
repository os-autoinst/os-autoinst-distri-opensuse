# Copyright (C) 2015-2018 SUSE LLC
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

# Summary: slenkins support
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;
use opensusebasetest 'firewall';

sub run {
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

    # we have to completely stop wicked - bsc#981651
    type_string("rcwickedd stop\n");
    configure_hostname(get_var('SLENKINS_NODE'));

    # Support server can start after network is on
    barrier_wait 'HOSTNAMES_CONFIGURED', $control_id;

    mutex_wait('support_server_ready', $control_id);
    configure_dhcp();

    if ($control_settings->{"SUPPORT_SERVER_ROLES"} !~ /\bdns\b/) {
        # dns on control node (supportserver) is not configured
        # -> use external dns
        configure_static_dns(get_host_resolv_conf());
    }
    # else use the supportserver dns configured via dhcp

    my $conf_script = "zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites\n";

    my $i = 0;
    if (get_var('FOREIGN_REPOS')) {
        foreach (split(/[\s,]+/, get_var('FOREIGN_REPOS'))) {
            if ($_ =~ /^http.*\.repo$/) {
                $conf_script .= "zypper -n --no-gpg-checks ar '" . $_ . "'\n";
            }
            else {
                $conf_script .= "zypper -n --no-gpg-checks ar '" . $_ . "' REPO_$i" . "\n";
                $i++;
            }
        }
    }

    if (get_var('SLENKINS_INSTALL')) {
        $conf_script
          .= "zypper -n --no-gpg-checks in " . join(' ', split(/[\s,]+/, get_var('SLENKINS_INSTALL'))) . "\n";
    }

    my $firewallservice = opensusebasetest::firewall;

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
        systemctl disable $firewallservice
        systemctl stop $firewallservice
        systemctl restart sshd
    ";
    script_output($conf_script, get_var('FOREIGN_REPOS') ? 1500 : 200);

    type_string("cat /var/log/messages >/dev/$serialdev\n");
    # send messages logged during the testsuite runtime to serial
    type_string("journalctl -f >/dev/$serialdev\n");

    mutex_create(get_var('SLENKINS_NODE'));

    wait_for_children;
}

sub test_flags {
    return {fatal => 1};
}

1;

