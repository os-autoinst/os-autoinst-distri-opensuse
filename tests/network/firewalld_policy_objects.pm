# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: firewalld apache2
# Summary: Test Firewalld Policy Feature
#            - setup multimachine test with described architecture
#            - test connection between server and client machine (and vice-versa). Will work in both directions
#            - create two zones in the firewall net0 and net1 interfaces: my-internal and my-external
#            - create two policies int-to-ext and ext-to-int for both directions between the zones
#            - create some custom rules to allow connections in one direction only (client to server)
#            - test again connectivity, expecting client to server to work, and the other way around to fail
#
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>
#
# Network Architecture:
# -------------+-----------------------------+------------------------------------------------------------------------10.0.2.0/24
#              |                             |
#         net0 |                        net0 |
#   10.0.2.102 |                  10.0.2.101 |
#              +----------------+             +----------------+               +----------------+
#              | Server         |             |Firewall        |               | Client         |
#              |                |             |                |               |                |
#              +----------------+             +----------------+               +----------------+
#                                                              |net1                            |net0
#                                                              |10.0.3.101                      |10.0.3.102
#                                                              |                                |
# -------------------------------------------------------------+--------------------------------+----------------------10.0.3.0/24


use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network qw(configure_default_gateway configure_static_ip configure_static_dns get_host_resolv_conf parse_network_configuration);
use utils 'zypper_call';
use Utils::Systemd 'disable_and_stop_service';
use version_utils qw(is_sle);

my $FW_EXT_IP = '10.0.2.101';
my $FW_INT_IP = '10.0.3.101';
my $SRV_IP    = '10.0.2.102';
my $SRV_PORT  = '80';
my $CLI_IP    = '10.0.3.102';

sub set_ip {
    my ($ip, $nic) = @_;
    script_run "arping -w 1 -I $nic $ip";    # check for duplicate IP
    assert_script_run "echo \"STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR='$ip/24'\nMTU='1458'\" > /etc/sysconfig/network/ifcfg-$nic";
    assert_script_run "rcnetwork restart";
    assert_script_run "ip addr";
}

sub configure_machines {
    my ($self, $hostname, $net0, $net1) = @_;

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);
    configure_default_gateway;

    if ($hostname eq "firewall") {
        record_info 'Setting up Firewall machine';
        set_ip($FW_EXT_IP, $net0);
        set_ip($FW_INT_IP, $net1);
        assert_script_run("sysctl -w net.ipv4.ip_forward=1");

    } elsif ($hostname eq "server") {
        record_info 'Setting up Server machine';
        set_ip($SRV_IP, $net0);
        assert_script_run("ip route add 10.0.3.0/24 via $FW_EXT_IP");

    } elsif ($hostname eq "client") {
        record_info 'Setting up Client machine';
        set_ip($CLI_IP, $net0);
        assert_script_run("ip route add default via $FW_INT_IP");
    }
    configure_static_dns(get_host_resolv_conf());
}

sub start_webserver {
    # Install and start webserver
    record_info 'Setting up Webserver';

    zypper_call('in apache2');
    assert_script_run('mkdir /srv/www/htdocs/mysite');
    assert_script_run('echo "mySecretInformation" > /srv/www/htdocs/mysite/hostedfile.txt');

    assert_script_run('echo "<VirtualHost *:80>" >> /etc/apache2/conf.d/mysite.conf');
    assert_script_run('echo "  DocumentRoot /srv/www/htdocs/mysite" >> /etc/apache2/conf.d/mysite.conf');
    assert_script_run('echo "</VirtualHost>" >> /etc/apache2/conf.d/mysite.conf');
    assert_script_run('systemctl restart apache2');
}

sub check_result {
    # Compares two given exit codes
    my ($result, $expected) = @_;
    if ($result ne $expected) {
        die "Result of last command is: $result. I was expecting: $expected";
    }
}

sub connection_test {
    # Tests connection from Client to Server machines and vice-versa. Http GET and ping are used.
    # Results are compared with given expected ones
    my ($hostname, $client_wget_result, $client_ping_result, $server_wget_result, $server_ping_result) = @_;
    my $result = "100";

    if ($hostname eq "client") {
        record_info 'Client to Server connection test';
        $result = script_run("wget $SRV_IP:$SRV_PORT/hostedfile.txt");
        check_result($result, $client_wget_result);

        $result = script_run("ping -c 3 $SRV_IP");
        check_result($result, $client_ping_result);

    } elsif ($hostname eq "server") {
        record_info 'Server to Client connection test';
        $result = script_run("wget $CLI_IP:$SRV_PORT/hostedfile.txt");
        check_result($result, $server_wget_result);

        $result = script_run("ping -c 3 $CLI_IP");
        check_result($result, $server_ping_result);
    }
}

sub configure_firewall_policies {
    # Create new zones and policies for the test
    my ($net0, $net1) = @_;
    assert_script_run("systemctl start firewalld");
    assert_script_run("firewall-cmd --permanent --new-zone=my-external");
    assert_script_run("firewall-cmd --permanent --new-zone=my-internal");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("firewall-cmd --zone=my-external --change-interface=$net0");
    assert_script_run("firewall-cmd --zone=my-internal --change-interface=$net1");
    assert_script_run("firewall-cmd --permanent --new-policy=int-to-ext");
    assert_script_run("firewall-cmd --permanent --new-policy=ext-to-int");

    assert_script_run("firewall-cmd --permanent --policy int-to-ext --add-ingress-zone=my-internal");
    assert_script_run("firewall-cmd --permanent --policy int-to-ext --add-egress-zone=my-external");
    assert_script_run("firewall-cmd --permanent --policy ext-to-int --add-ingress-zone=my-external");
    assert_script_run("firewall-cmd --permanent --policy ext-to-int --add-egress-zone=my-internal");
    assert_script_run("firewall-cmd --runtime-to-permanent");

    # Internal to External policy: Allow http and icmp
    assert_script_run("firewall-cmd --permanent --policy int-to-ext --add-rich-rule='rule family=ipv4 service name=http accept'");
    assert_script_run("firewall-cmd --permanent --policy int-to-ext --add-rich-rule='rule family=ipv4 protocol value=icmp accept'");
    # External to Internal policy: Reject http and icmp
    assert_script_run("firewall-cmd --permanent --policy ext-to-int --add-rich-rule='rule family=ipv4 service name=http reject'");
    assert_script_run("firewall-cmd --permanent --policy ext-to-int --add-rich-rule='rule family=ipv4 protocol value=icmp reject'");

    assert_script_run("firewall-cmd --reload");
}

sub run {
    my ($self) = @_;
    # Hostname var comes from the Test Suite and is used to distinguish between the 3 machines
    my $hostname = get_var('HOSTNAME');

    # Network interfaces names. Default is for openSUSE
    my $net0 = "ens4";
    my $net1 = "ens5";

    if (is_sle()) {
        $net0 = "eth0";
        $net1 = "eth1";
    }

    if ($hostname eq "firewall") {
        barrier_create 'BARRIER_READY',          3;
        barrier_create 'CONFIGURATION_DONE',     3;
        barrier_create 'SERVER_READY',           3;
        barrier_create 'CONNECTION_TEST_1_DONE', 3;
        barrier_create 'FIREWALL_POLICY_READY',  3;
        barrier_create 'CONNECTION_TEST_2_DONE', 3;
        mutex_create 'barrier_setup_done';
    }
    mutex_wait 'barrier_setup_done';

    $self->select_serial_terminal;
    barrier_wait 'BARRIER_READY';

    configure_machines($self, $hostname, $net0, $net1);
    barrier_wait 'CONFIGURATION_DONE';

    if ($hostname eq "server" || $hostname eq "client") {
        start_webserver();
    }
    barrier_wait 'SERVER_READY';

    # This test expects all communication to work (Cli->Srv and Srv->Cli)
    connection_test($hostname, 0, 0, 0, 0);
    barrier_wait 'CONNECTION_TEST_1_DONE';

    if ($hostname eq "firewall") {
        configure_firewall_policies($net0, $net1);
    }
    barrier_wait 'FIREWALL_POLICY_READY';

    # This test expects Cli->Srv communication to work, but not vice-versa
    connection_test($hostname, 0, 0, 4, 1);
    barrier_wait 'CONNECTION_TEST_2_DONE';
}

1;

