# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use mmapi 'wait_for_children';
use mm_network;
use utils qw(zypper_call script_retry);
use Utils::Systemd qw(disable_and_stop_service systemctl);
use version_utils 'is_sle';

my $FW_EXT_IP = '10.0.2.101';
my $FW_INT_IP = '10.0.3.101';
my $SRV_IP = '10.0.2.102';
my $SRV_PORT = '80';
my $CLI_IP = '10.0.3.102';

sub configure_machines {
    my ($self, $hostname, $net0, $net1) = @_;

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);

    my $is_nm = is_networkmanager();

    if ($hostname eq "firewall") {
        record_info 'Setting up Firewall machine';
        configure_static_ip(ip => "$FW_EXT_IP/24", device => $net0, is_nm => $is_nm);
        configure_static_ip(ip => "$FW_INT_IP/24", device => $net1, is_nm => $is_nm);
        configure_default_gateway(is_nm => $is_nm, device => $net0);
        configure_static_dns(get_host_resolv_conf(), is_nm => $is_nm);
        assert_script_run("sysctl -w net.ipv4.ip_forward=1");
        restart_networking(is_nm => $is_nm);
    } elsif ($hostname eq "server") {
        record_info 'Setting up Server machine';
        configure_static_ip(ip => "$SRV_IP/24", device => $net0, is_nm => $is_nm);
        configure_default_gateway(is_nm => $is_nm, device => $net0);
        configure_static_dns(get_host_resolv_conf(), is_nm => $is_nm);
        restart_networking(is_nm => $is_nm);
        assert_script_run("ip route add 10.0.3.0/24 via $FW_EXT_IP");
        assert_script_run("ip route add 10.0.2.2 dev $net0");
        assert_script_run("ip route show");
    } elsif ($hostname eq "client") {
        record_info 'Setting up Client machine';
        configure_static_ip(ip => "$CLI_IP/24", device => $net0, is_nm => $is_nm);
        configure_static_dns(get_host_resolv_conf(), is_nm => $is_nm);
        restart_networking(is_nm => $is_nm);
        assert_script_run("ip route add default via $FW_INT_IP");
        assert_script_run("ip route add 10.0.2.2 dev $net0");
        assert_script_run("ip route show");
    }
}

sub start_webserver {
    # Install and start webserver
    record_info 'Setting up Webserver';

    zypper_call('in apache2');
    assert_script_run('mkdir /srv/www/htdocs/mysite');
    assert_script_run('echo "mySecretInformation" > /srv/www/htdocs/mysite/hostedfile.txt');
    assert_script_run "curl " . data_url('firewalld_policy_objectsmysite.conf') . " -o /etc/apache2/conf.d/mysite.conf";
    systemctl('restart apache2');
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
    if (script_run("firewall-cmd --runtime-to-permanent")) {
        record_soft_failure("Committing zone change failed due to gh#firewalld/firewalld#890");
        # As workaround, do it in the permanent config and the --reload later will activate it
        assert_script_run("firewall-cmd --permanent --zone=my-external --change-interface=$net0");
        assert_script_run("firewall-cmd --permanent --zone=my-internal --change-interface=$net1");
    }

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
        barrier_create 'BARRIER_READY', 3;
        barrier_create 'CONFIGURATION_DONE', 3;
        barrier_create 'SERVER_READY', 3;
        barrier_create 'CONNECTION_TEST_1_DONE', 3;
        barrier_create 'FIREWALL_POLICY_READY', 3;
        barrier_create 'CONNECTION_TEST_2_DONE', 3;
        mutex_create 'barrier_setup_done';
    }
    mutex_wait 'barrier_setup_done';

    $self->select_serial_terminal;
    barrier_wait 'BARRIER_READY';

    configure_machines($self, $hostname, $net0, $net1);
    barrier_wait 'CONFIGURATION_DONE';

    # Check the Internet connectivity - it may take a moment
    script_retry('ping -c3 google.com', retry => 12, delay => 5, die => 0);


    if ($hostname eq "server" || $hostname eq "client") {
        # Install and start webserver
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

    wait_for_children() if ($hostname eq "firewall");
}

1;

