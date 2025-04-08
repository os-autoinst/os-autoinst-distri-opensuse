# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup simple network topology for bonding tests
#
# Maintainer: QE Core <qe-core@suse.de>
#
use base 'consoletest';
use strict;
use warnings;
use testapi;
use power_action_utils "power_action";
use serial_terminal 'select_serial_terminal';
use network_utils qw(get_nics cidr_to_netmask is_nm_used is_wicked_used delete_all_existing_connections set_nics_link_speed_duplex check_connectivity_to_host_with_retry set_resolv set_nic_dhcp_auto reload_connections_until_all_ips_assigned);
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);
use lockapi;
use utils;
use version_utils;
use registration qw(runtime_registration add_suseconnect_product);
use transactional qw(trup_call process_reboot);

my $server_ip = "10.0.2.101";
my $subnet = "/24";
my $gateway = "10.0.2.2";

my $dhcpd_server_image_name = get_var "DHCPD_SERVER_IMAGE_NAME";
my $dhcpd_server_image_registry = get_var "DHCPD_SERVER_IMAGE_REGISTRY";

my $public_dns_string = get_var "PUBLIC_DNS", "8.8.8.8,8.8.4.4";
my $scc_dns_string = get_var "SCC_DNS", "";
my $registry_dns_string = get_var "REGISTRY_DNS", "";
my $container_primary_dns_string = get_var "CONTAINER_PRIMARY_DNS", "8.8.8.8,8.8.4.4";
my $override_dns_string = get_var "OVERRIDE_DNS", "";

# Split the DNS strings into arrays only if the variable is defined and not empty
my @public_dns = defined($public_dns_string) && $public_dns_string ne "" ? split(",", $public_dns_string) : ();
my @scc_dns = defined($scc_dns_string) && $scc_dns_string ne "" ? split(",", $scc_dns_string) : ();
my @registry_dns = defined($registry_dns_string) && $registry_dns_string ne "" ? split(",", $registry_dns_string) : ();
my @container_primary_dns = defined($container_primary_dns_string) && $container_primary_dns_string ne "" ? split(",", $container_primary_dns_string) : ();

my $requires_scc_registration = is_sle_micro || is_sle;

sub install_pkgs {
    my ($self, @pkgs) = @_;
    my @to_install;    # Array to store packages that need to be installed

    # Check if each package is already installed
    foreach my $pkg (@pkgs) {
        my $is_installed = script_run("rpm -q $pkg");    # Returns 0 if installed, non-zero if not
        if ($is_installed != 0) {
            push @to_install, $pkg;    # Add package to install list if not installed
        } else {
            record_info("Package already installed", "$pkg is already installed");
        }
    }

    # Proceed only if there are packages to install
    if (@to_install) {
        my $pkg_list = join ' ', @to_install;    # Convert @to_install to a space-separated string
        if (is_transactional) {
            assert_script_run "rebootmgrctl set-strategy instantly";
            record_info("Installing packages", "Using transactional-update, requires reboot: $pkg_list");
            trup_call "reboot pkg install $pkg_list";
            process_reboot(expected_grub => 1);
            select_serial_terminal;
        } else {
            record_info("Installing packages", "Using zypper for installation: $pkg_list");
            zypper_call "in $pkg_list";
        }
    } else {
        record_info("No installation needed", "All packages are already installed");
    }
}

sub setup_kea_container {
    my (%args) = @_;
    $args{nic} //= "eth0";
    $args{container_name} //= "dhcpd-server";
    $args{registry} //= $dhcpd_server_image_registry;
    $args{image_name} //= $dhcpd_server_image_name;

    record_info("SETUP_DHCPD_CONTAINER");

    assert_script_run("podman pull $args{registry}$args{image_name}", timeout => 300);

    # Start assembling the command as an AoA (Array of Arrays)
    my @podman_cmd = (
        ["podman", "run", "-itd", "--net=host", "--privileged"],
        ["-v", "/etc/kea:/etc/kea"],
        $override_dns_string ne "" ? ["-e", "OVERRIDE_DNS=$override_dns_string"] : (),
        ["--name", $args{container_name}],
        [$args{image_name}],
        ["kea-dhcp4", "-c", "/etc/kea/kea-dhcp4.conf"]
    );

    # Filter out any empty arrays
    @podman_cmd = grep { @$_ } @podman_cmd;

    # Flatten AoA into a single string command
    my $podman_cmd_string = join(" ", map { join(" ", @$_) } @podman_cmd);

    # Run the container with the complete command
    assert_script_run($podman_cmd_string, timeout => 120);

    # Verify the container is running
    validate_script_output('podman ps', sub { m/$args{container_name}/ });
    validate_script_output('ss -lnp', sub { /$server_ip:67/ });
}

sub setup_server_network {
    my ($nics_ref) = @_;
    my @nics = @$nics_ref;
    my $nic0 = $nics[0];

    record_info("SETUP_SERVER_NETWORK");

    # Bring down all non-loopback interfaces except the first one
    foreach my $nic (@nics[1 .. $#nics]) {
        record_info("Non-loopback interface $nic detected, bringing it down...");
        assert_script_run("ip link set $nic down");
    }

    delete_all_existing_connections();

    my $netmask = cidr_to_netmask($subnet);

    if (is_nm_used()) {
        # Setting IP and bringing the connection up
        assert_script_run "nmcli con add type ethernet ifname $nic0 con-name $nic0";
        assert_script_run "nmcli con modify $nic0 ipv4.addresses ${server_ip}${subnet} ipv4.gateway $gateway ipv4.routes '0.0.0.0/0 $gateway' ipv4.method manual";
        assert_script_run "nmcli con modify $nic0 connection.autoconnect yes";
        assert_script_run "nmcli con up $nic0";
    }

    if (is_wicked_used()) {
        # Wicked configuration: setting IP and Netmask
        assert_script_run "echo 'BOOTPROTO=static' > /etc/sysconfig/network/ifcfg-$nic0";
        assert_script_run "echo 'STARTMODE=auto' >> /etc/sysconfig/network/ifcfg-$nic0";
        assert_script_run "echo 'IPADDR=$server_ip' >> /etc/sysconfig/network/ifcfg-$nic0";
        assert_script_run "echo 'GATEWAY=$gateway' >> /etc/sysconfig/network/ifcfg-$nic0";
        assert_script_run "echo 'NETMASK=$netmask' >> /etc/sysconfig/network/ifcfg-$nic0";

        my $route_config_file = "/etc/sysconfig/network/ifroute-$nic0";

        # Delete existing route configuration if it exists
        script_run "rm -f $route_config_file";

        # Create a new route configuration file
        assert_script_run "echo 'default $gateway dev $nic0' > $route_config_file";

        systemctl 'restart wicked';
    }
}

sub configure_kea {
    my (%args) = @_;
    $args{nic} //= "eth0";
    assert_script_run("mkdir -p /etc/kea/ || true");
    assert_script_run("curl -v -o /etc/kea/kea-dhcp4.conf  " . data_url("network_bonding/kea-dhcp4.conf"));
    assert_script_run("sed -i \"s/eth0/$args{nic}/g\" /etc/kea/kea-dhcp4.conf");
}

sub configure_dnsmasq {
    my (%args) = @_;
    $args{nic} //= "eth0";
    assert_script_run("curl -v -o /etc/dnsmasq.conf  " . data_url("network_bonding/dnsmasq.conf"));
    assert_script_run("sed -i \"s/eth0/$args{nic}/g\" /etc/dnsmasq.conf");

    # Remove existing server lines from /etc/dnsmasq.conf
    assert_script_run('sed -i "/^server=/d" /etc/dnsmasq.conf');

    foreach my $server (@container_primary_dns) {
        record_info("DNS", "Adding general DNS server: $server");
        assert_script_run("echo 'server=$server' >> /etc/dnsmasq.conf");
    }

    my @domain_records = split(';', $override_dns_string);

    foreach my $record (@domain_records) {
        my ($domain, $dns_ips) = split(':', $record);
        my @ips = split(',', $dns_ips);

        foreach my $ip (@ips) {
            record_info("DNS Override", "Adding custom DNS entry for $domain: $ip");
            assert_script_run("echo 'server=/$domain/$ip' >> /etc/dnsmasq.conf");
        }
    }
}

sub setup_server {
    my ($self, $nics_ref) = @_;
    my @nics = @$nics_ref;
    my $nic0 = $nics[0];
    my @local_ns = ($server_ip);

    record_info("SETUP_SERVER");
    setup_server_network(\@nics);

    set_resolv(nameservers => \@public_dns);

    set_resolv(nameservers => \@scc_dns) if scalar(@scc_dns) > 0;
    runtime_registration() if $requires_scc_registration;
    add_suseconnect_product("sle-module-containers") if is_sle('<16');

    install_pkgs($self, "podman", "ethtool", "dnsmasq");

    set_nics_link_speed_duplex({
            nics => \@nics,
            speed => 1000,    # assuming a speed of 1000 Mbps
            duplex => 'full',    # assuming full duplex
            autoneg => 'off'    # assuming autoneg is off
    });

    configure_dnsmasq(nic => $nic0);
    assert_script_run("dnsmasq");
    validate_script_output('ps aux | grep [d]nsmasq', sub { /dnsmasq/ });
    validate_script_output('ss -uln', sub { /$server_ip:53/ });
    validate_script_output('ss -tln', sub { /$server_ip:53/ });

    configure_kea(nic => $nic0);
    set_resolv(nameservers => \@registry_dns) if scalar(@registry_dns) > 0;
    setup_kea_container();

    set_resolv(nameservers => \@local_ns);
    check_connectivity_to_host_with_retry($nic0, "conncheck.opensuse.org");

    barrier_wait "SERVER_SETUP_DONE";
    barrier_wait "BONDING_TESTS_DONE";
}

sub setup_client_network {
    my ($nics_ref) = @_;
    my @nics = @$nics_ref;
    my $nic0 = $nics[0];
    my $timeout = 180;    # Timeout in seconds
    my $retry_interval = 10;    # Interval between retries in seconds

    record_info("SETUP_CLIENT_NETWORK");
    delete_all_existing_connections();
    set_nic_dhcp_auto($nic0);
    reload_connections_until_all_ips_assigned(nics => [$nic0]);
    check_connectivity_to_host_with_retry($nic0, "conncheck.opensuse.org");
}

sub setup_client {
    my ($self, $nics_ref) = @_;
    my @nics = @$nics_ref;

    record_info("SETUP_CLIENT");
    setup_client_network(\@nics);

    runtime_registration() if $requires_scc_registration;
    install_pkgs($self, "ethtool");
}

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    my $is_server = ($hostname =~ /target/);

    if ($is_server) {
        barrier_create "SERVER_SETUP_DONE", 2;
        barrier_create "BONDING_TESTS_DONE", 2;
        mutex_create 'barrier_setup_mm_done';
    }
    mutex_wait 'barrier_setup_mm_done';

    select_serial_terminal;

    my @nics = get_nics([]);

    assert_script_run("echo \"$server_ip server master\" >> /etc/hosts");

    disable_and_stop_service($self->firewall, ignore_failure => 1) if check_unit_file($self->firewall);
    disable_and_stop_service("apparmor", ignore_failure => 1) if check_unit_file("apparmor");

    setup_server($self, \@nics) if $is_server;

    unless ($is_server) {
        barrier_wait "SERVER_SETUP_DONE";
        setup_client($self, \@nics);
    }
}

1;
