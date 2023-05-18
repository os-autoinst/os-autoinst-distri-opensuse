# SUSE's openQA tests
#
# Copyright ?? 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup dns service for virtual machines to have dns compatiable name.
# Maintainer: Wayne Chen <wchen@suse.com>

use base "virt_autotest_base";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    my $wait_script = "180";
    my $dns_bash_script_name = "setup_dns_service.sh";
    my $dns_bash_script_url = data_url("virt_autotest/$dns_bash_script_name");
    my $dns_forward_domain = "testvirt.net";
    my $dns_reverse_domain = "123.168.192";
    my $dns_server_ipaddr = "192.168.123.1";
    my $download_bash_script = "curl -s -o ~/$dns_bash_script_name $dns_bash_script_url";
    script_output($download_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);
    my $execute_bash_script = "chmod +x ~/$dns_bash_script_name && ~/$dns_bash_script_name -f $dns_forward_domain -r $dns_reverse_domain -s $dns_server_ipaddr";
    script_output($execute_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);

    upload_logs("/var/log/virt_dns_setup.log");
    diag("SSH Connections to all virtual machines with their DNS names and without inputting login passwords already work.");
}

sub post_fail_hook {
    my $self = shift;

    diag("There is something wrong with establishing dns service for vm guest or ssh connection to vm guest without inputting login password.");
    diag("Module setup_dns_service post fail hook starts.");
    script_run("cat /var/lib/named/testvirt.net.zone");
    save_screenshot;
    script_run("cat /var/lib/named/123.168.192.zone");
    save_screenshot;
    script_run("mv /etc/resolv.conf.orig /etc/resolv.conf; mv /etc/named.conf.orig /etc/named.conf; mv /etc/ssh/ssh_config.orig /etc/ssh/ssh_config; mv /etc/dhcpd.conf.orig /etc/dhcpd.conf");
    script_run("sed -irn '/^nameserver 192\\.168\\.123\\.1/d' /etc/resolv.conf");
    script_run("rm /var/lib/named/testvirt.net.zone; rm /var/lib/named/123.168.192.zone");

    my $get_os_installed_release = "lsb_release -r | grep -oE \"[[:digit:]]{2}\"";
    my $os_installed_release = script_output($get_os_installed_release, 30, type_command => 0, proceed_on_failure => 0);
    if ($os_installed_release gt '11') {
        script_run("systemctl stop named.service");
        script_run("systemctl disable named.service");
    }
    else {
        script_run("service named stop");
    }

    my $vm_types = "sles|win";
    my $get_vm_hostnames = "virsh list  --all | grep -E \"${vm_types}\" | awk \'{print \$2}\'";
    my $vm_hostnames = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
    }
    upload_logs("/var/log/virt_dns_setup.log");
}

1;
