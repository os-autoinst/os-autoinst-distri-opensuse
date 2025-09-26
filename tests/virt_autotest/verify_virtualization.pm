# VERIFY VIRTUALIZATION FUNCTIONALITY MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module verifies functionality on virtualization system, including
# system information, hypervisor, registration, host/guest network, guest storage
# and etc.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package verify_virtualization;

use base "opensusebasetest";
use Tie::IxHash;
use testapi;
use utils;
use version_utils;
use virt_autotest::utils;
use Utils::Architectures;
use Utils::Logging qw(upload_coredumps);
use virt_utils;
use virt_autotest::virtual_network_utils;
use virt_autotest::domain_management_utils;
use mm_network qw(is_networkmanager);

tie our %guest_matrix, 'Tie::IxHash', ();
our @guest_list = ();

sub run {
    my $self = shift;

    select_backend_console(init => 0);
    $self->verify_bootloader;
    $self->verify_system;
    $self->verify_hypervisor;
    $self->verify_network;
    $self->verify_registration;
    $self->verify_guest_number;
    $self->verify_guest_network;
    $self->verify_guest_storage;
    return $self;
}

sub verify_bootloader {
    my $self = shift;

    my %osinfo = script_output("cat /etc/os-release") =~ /^([^#]\S+)="?([^"\r\n]+)"?$/gm;
    %osinfo = map { uc($_) => $osinfo{$_} } keys %osinfo;
    if (script_run("ls -d /sys/firmware/efi") != 0) {
        record_info("Not uefi boot on system $osinfo{VERSION}", "Current system is running $osinfo{ID} $osinfo{VERSION} which does not use uefi boot");
    }
    else {
        record_info("UEFI boot on system $osinfo{VERSION}", "Current system is running $osinfo{ID} $osinfo{VERSION} which boots with uefi firmware");
    }
    return $self;
}

sub verify_system {
    my $self = shift;

    record_info("OS release", script_output("cat /etc/os-release"));
    record_info("Grub config", script_output("cat /boot/grub2/grub.cfg"));
    my %osinfo = script_output("cat /etc/os-release") =~ /^([^#]\S+)="?([^"\r\n]+)"?$/gm;
    %osinfo = map { uc($_) => $osinfo{$_} } keys %osinfo;
    if (uc($osinfo{VERSION}) ne uc(get_required_var('VERSION'))) {
        record_info("System is not expected os " . get_required_var('DISTRI') . " " . get_required_var('VERSION'), "Current system is running $osinfo{ID} $osinfo{VERSION}", result => 'fail');
        die("System is not running the expected os");
    }
    return $self;
}

sub verify_hypervisor {
    my $self = shift;

    if (is_xen_host) {
        double_check_xen_role;
    }
    elsif (is_kvm_host) {
        check_kvm_modules if (is_x86_64);
    }
    return $self;
}

sub verify_network {
    my $self = shift;

    if (!is_networkmanager and is_sle('>=16')) {
        record_info(get_required_var('DISTRI') . " " . get_required_var('VERSION') . " should run NetworkManager", "NetworkManager is not running", result => 'fail');
        if (script_run("rpm -q NetworkManager") != 0) {
            record_info(get_required_var('DISTRI') . " " . get_required_var('VERSION') . " should have NetworkManager installed", "NetworkManager is not installed", result => 'fail');
        }
    }
    record_info("IP address", script_output("ip addr show"));
    record_info("IP routes", script_output("ip route show all"));
    record_info("Content of /etc/resolv.conf", script_output("cat /etc/resolv.conf"));
    return $self;
}

sub verify_registration {
    my $self = shift;

    record_info("Registration status", script_output("SUSEConnect --status-text"));
    my $scc_register = get_var('HOST_SCC_REGISTER') ? get_var('HOST_SCC_REGISTER') : get_var('SCC_REGISTER', '');
    if (($scc_register eq 'installation') and script_run("SUSEConnect -s | grep -i \"\\\"status\\\":\\\"Registered\\\"\"") != 0) {
        record_info("System not registered", "System " . get_required_var('DISTRI') . " " . get_required_var('VERSION') . " is supposed to be registered. Please check further.", result => 'fail');
    }
    return $self;
}

sub verify_guest_number {
    my $self = shift;

    record_info("Show all guests", script_output("virsh list --all", proceed_on_failure => 1));
    my $guest_in_number = scalar split(/\|/, get_var('UNIFIED_GUEST_LIST', get_var('GUEST_LIST', '')));
    @guest_list = split(/\n/, script_output("virsh list --all --name | grep -v Domain-0 | grep .", proceed_on_failure => 1));
    my $guest_on_system = scalar @guest_list;
    if ($guest_in_number == 0) {
        record_info("No guest expected", "No guest expected from setting UNIFIED_GUEST_LIST or GUEST_LIST");
    }
    else {
        die("No guest found on system") if ($guest_on_system == 0);
        record_info("Guest number incorrect", "There are $guest_on_system guests found on system but $guest_in_number are expected", result => 'fail') if ($guest_on_system != $guest_in_number);
    }
    return $self;
}

sub verify_guest_network {
    my ($self, %args) = @_;
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{keyfile} //= get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_rsa');

    record_info("List virtual networks", script_output("virsh net-list --all"));
    record_info("List guests", script_output("virsh list --all"));
    my $ssh_command = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $args{keyfile}";
    if (script_run("ls $args{keyfile}") != 0) {
        assert_script_run("clear && ssh-keygen -b 2048 -t rsa -q -N \"\" -f $args{keyfile} <<< y");
        assert_script_run("chmod 600 $args{keyfile} $args{keyfile}.pub");
    }

    my $ret = 0;
    if (scalar @guest_list > 0) {
        foreach my $guest (@guest_list) {
            save_screenshot;
            # Retrieve guest network config and populate into $guest_matrix{$guest}
            tie my %single_guest_matrix, 'Tie::IxHash', (macaddr => '', ipaddr => '', nettype => '', netname => '', netmode => '', staticip => 'no');
            $guest_matrix{$guest} = \%single_guest_matrix;
            my $temp = 1;
            $temp = script_run("virsh dumpxml $guest > $args{confdir}/$guest.xml");
            record_info("Guest $guest config", script_output("cat $args{confdir}/$guest.xml"));
            virt_autotest::virtual_network_utils::check_guest_network_config(guest => $guest, matrix => \%guest_matrix);

            # Configure bridge br123 services if it is being used by guest
            if ($guest_matrix{$guest}{netname} eq 'br123') {
                virt_autotest::virtual_network_utils::config_domain_resolver(resolvip => '192.168.123.1', domainname => 'testvirt.net');
                my $dnsmasq_command = "/usr/sbin/dnsmasq --bind-dynamic --listen-address=192.168.123.1 --dhcp-range=192.168.123.2,192.168.123.254,255.255.255.0,8h --interface=$guest_matrix{$guest}{netname} --dhcp-authoritative --no-negcache --dhcp-option=option:router,192.168.123.1 --log-queries --log-dhcp --dhcp-sequential-ip --dhcp-client-update --domain=testvirt.net --local=/testvirt.net/ --log-dhcp --dhcp-fqdn --dhcp-sequential-ip --dhcp-client-update --domain-needed --dns-loop-detect --server=/testvirt.net/192.168.123.1 --server=/123.168.192.in-addr.arpa./192.168.123.1 --no-daemon";
                my $dnsmasq_command_query = "/usr/sbin/dnsmasq --bind-dynamic --listen-address=192.168.123.1.*--dhcp-range=192.168.123.2,192.168.123.254,255.255.255.0,8h --interface=$guest_matrix{$guest}{netname} --dhcp-authoritative --no-negcache --dhcp-option=option:router,192.168.123.1.*--server=/testvirt.net/192.168.123.1 --server=/123.168.192.in-addr.arpa./192.168.123.1";
                if (!script_output("ps ax | grep -i -E \"$dnsmasq_command_query\" | grep -v grep | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1)) {
                    script_run("((nohup $dnsmasq_command) &)");
                    my $find_dnsmasq = script_output("ps ax | grep -i -E \"$dnsmasq_command_query\" | grep -v grep | awk \'{print \$1}\'", type_command => 1, proceed_on_failure => 1);
                    $temp |= 1 && record_info("DHCP service failed on $guest_matrix{$guest}{netname}", "Command to start DHCP service is $dnsmasq_command\n" . script_output("ps axu | grep -i dnsmasq"), result => 'fail') if (!$find_dnsmasq);
                }
                virt_autotest::virtual_network_utils::config_network_device_policy(logdir => $args{confdir}, name => $guest, netdev => $guest_matrix{$guest}{netname});
            }

            # Start guest
            $temp |= script_run("virsh start $guest") if (script_run("virsh reboot $guest") != 0);

            # Obtain guest ip address
            virt_autotest::virtual_network_utils::check_guest_network_address(guest => $guest, matrix => \%guest_matrix);
            virt_autotest::domain_management_utils::show_guest();
            record_info("Guest $guest network config info",
                "macaddr:$guest_matrix{$guest}{macaddr}, ipaddr:$guest_matrix{$guest}{ipaddr}, nettype:$guest_matrix{$guest}{nettype},
	        netmode:$guest_matrix{$guest}{netmode}, netname:$guest_matrix{$guest}{netname}, staticip:$guest_matrix{$guest}{staticip}");
            $temp |= script_run("virsh domiflist $guest");

            # Verify guest connectivity
            if ($guest_matrix{$guest}{ipaddr} and script_retry("ping -c5 $guest_matrix{$guest}{ipaddr}", option => '--kill-after=1 --signal=9', delay => 1, retry => 60, die => 0) != 0) {
                record_info("Fail to ping guest $guest", "Guest $guest ip address is $guest_matrix{$guest}{ipaddr}", result => 'fail');
                $temp |= 1;
            }
            elsif (!$guest_matrix{$guest}{ipaddr}) {
                record_info("Fail to get guest $guest ip", "Guest $guest ip address can not be obtained", result => 'fail');
                $temp |= 1;
            }
            if (script_retry("nc -zvD $guest_matrix{$guest}{ipaddr} 22", option => '--kill-after=1 --signal=9', delay => 1, retry => 60, die => 0) != 0) {
                record_info("Port 22 not open on guest $guest", "Guest $guest ip address is $guest_matrix{$guest}{ipaddr}", result => 'fail');
                $temp |= 1;
            }
            if ($temp != 0) {
                $ret |= $temp;
                next;
            }
            if (script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest_matrix{$guest}{ipaddr} ls") != 0) {
                $temp |= 1;
                record_info("PubKey ssh failed on guest $guest", "Need to re-setup pubkey ssh to guest $guest $guest_matrix{$guest}{ipaddr}", result => 'fail');
                enter_cmd("clear", wait_still_screen => 3);
                enter_cmd("timeout --kill-after=1 --signal=9 30 ssh-copy-id -f -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $args{keyfile}.pub root\@$guest_matrix{$guest}{ipaddr}", wait_still_screen => 3);
                check_screen("password-prompt", 60);
                enter_cmd(get_var('_SECRET_GUEST_PASSWORD', ''), wait_screen_change => 50, max_interval => 1);
                wait_still_screen(35);
            }
            if (script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest_matrix{$guest}{ipaddr} ls") != 0) {
                record_info("Fail to ssh with pubkey on guest $guest", "ssh to guest $guest_matrix{$guest}{ipaddr} failed with pubkey", result => 'fail');
            }
            elsif ($guest_matrix{$guest}{netname} !~ /^(br0|default)$/i and script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest ls") != 0) {
                record_info("Failed to ssh guest $guest with domain name", "ssh to guest $guest failed with pubkey", result => 'fail');
            }
            $ret |= $temp;
        }
        die("Guest network verificatin failed") if ($ret != 0);
    }
    return $self;
}

sub verify_guest_storage {
    my ($self, %args) = @_;
    $args{keyfile} //= get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_rsa');

    my $ret = 0;
    my $ssh_command = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $args{keyfile}";
    if (scalar @guest_list > 0) {
        foreach my $guest (@guest_list) {
            save_screenshot;
            if (script_run("timeout --kill-after=1 --signal=9 20 $ssh_command root\@$guest_matrix{$guest}{ipaddr} \"echo VIRTUALIZATION > /tmp/test_guest_storage && rm -f -r /tmp/test_guest_storage\"") != 0) {
                record_info("Failed storage on guest $guest", "Storage test failed on guest $guest_matrix{$guest}{ipaddr}", result => 'fail');
                $ret |= 1;
            }
        }
        die("Guest storage verificatin failed") if ($ret != 0);
    }
    return $self;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    script_run("journalctl --all --dmesg > /var/log/full_journal_log");
    script_run("cp -r /etc/sysconfig/network/scripts > /var/log/etc_sysconfig_network_scripts");
    script_run("cp -r /etc/NetworkManager/system-connections > /var/log/etc_networkmanager_system_connections");
    script_run("iptables -L -n -v > /var/log/iptables_rules");
    virt_utils::collect_host_and_guest_logs(extra_host_log => '/var/log', extra_guest_log => '/root /var/log', full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_verify_virtualization');
    save_screenshot;
    upload_coredumps;
    save_screenshot;
    return $self;
}

1;
