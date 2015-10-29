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
use ttylogin;

sub run {
    my $self = shift;

    ttylogin('4', "root");

    my $configured = 0;
    my $ip_num     = 15;
    open(FH, '<', get_var('CASEDIR') . "/data/slenkins/" . get_var('SLENKINS_NODEFILE'));
    my $name;
    while (<FH>) {
        print "read $_\n";
        my ($var, $value) = split /\s+/, $_;
        print "read '$_' '$var' '$value'\n";
        if ($var eq 'node') {
            print "found name $value\n";
            $name = $value;

            if ($name eq get_var('SLENKINS_NODE')) {
                configure_default_gateway;
                configure_static_ip("10.0.2.$ip_num/24");
                configure_static_dns(get_host_resolv_conf());
                script_output("zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites", 100);
                $configured = 1;
            }
            $ip_num++;
        }
        elsif ($var eq 'install' && $name eq get_var('SLENKINS_NODE')) {
            print "found install $value\n";
            script_output("zypper -n --no-gpg-checks in $value\n", 100);
        }
    }
    close(FH);

    die "node '" . get_var('SLENKINS_NODE') . "'not found in " . get_var('SLENKINS_NODEFILE') unless $configured;

    script_output("
        useradd -m testuser
        mkdir /root/.ssh
        mkdir /home/testuser/.ssh
        curl -f -v " . autoinst_url . "/data/slenkins/ssh/id_rsa > /root/.ssh/id_rsa
        curl -f -v " . autoinst_url . "/data/slenkins/ssh/authorized_keys > /root/.ssh/authorized_keys
        cp /root/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys
        chown -R testuser /home/testuser/.ssh
        chmod 600 /root/.ssh/*
        chmod 700 /root/.ssh
        chmod 600 /home/testuser/.ssh/*
        chmod 700 /home/testuser/.ssh
        rcSuSEfirewall2 stop
        rcsshd restart
    ", 100);

    # send messages logged during the testsuite runtime to serial
    type_string("journalctl -f >/dev/$serialdev\n");

    mutex_create(get_var('SLENKINS_NODE'));

    while (1) {
        my $s = get_children_by_state('scheduled');
        my $r = get_children_by_state('running');
        next unless defined $s && defined $r;

        my $n = @$s + @$r;

        print "Waiting for $n jobs to finish\n";

        last if $n == 0;
        sleep 1;
    }

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
