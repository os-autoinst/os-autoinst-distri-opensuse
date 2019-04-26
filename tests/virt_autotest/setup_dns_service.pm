# SUSE's openQA tests
#
# Copyright ?? 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup dns service for virtual machines to have dns compatiable name.
# Maintainer: Wayne Chen <wchen@suse.com>

use base "virt_autotest_base";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    my $wait_script             = "180";
    my $dns_bash_script_url     = data_url("virt_autotest/setup_dns_service.sh");
    my $execute_dns_bash_script = "bash <(curl -s $dns_bash_script_url)";
    script_output($execute_dns_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);

    upload_logs("/var/log/virt_dns_setup.log");
    diag("SSH Connection to all virtual machines by using DNS names is working now");
}

sub post_fail_hook {
    my $self = shift;

    diag("There is something wrong with eastablishing dns service. At least one vm can not be reached by its dns name.");
    diag("Module setup_dns_service post fail hook starts.");
    for (my $i = 0; $i < 4; $i++) {
        script_run("head -n \$((($i+1)*50)) /etc/named.conf");
        save_screenshot;
    }
    script_run("cat /var/lib/named/testvirt.net.zone");
    save_screenshot;
    script_run("cat /var/lib/named/123.168.192.zone");
    save_screenshot;
    script_run("mv /etc/resolv.conf.orig /etc/resolv.conf; mv /etc/named.conf.orig /etc/named.conf");
    script_run("sed -irn '/^nameserver 192\\.168\\.123\\.1/d' /etc/resolv.conf");
    script_run("rm /var/lib/named/testvirt.net.zone; rm /var/lib/named/123.168.192.zone");

    my $get_os_installed_release = "lsb_release -r | grep -oE \"[[:digit:]]{2}\"";
    my $os_installed_release     = script_output($get_os_installed_release, 30, type_command => 0, proceed_on_failure => 0);
    if ($os_installed_release gt '11') {
        script_run("systemctl stop named.service");
        script_run("systemctl disable named.service");
    }
    else {
        script_run("service named stop");
    }

    my $get_vm_hostnames   = "virsh list  --all | grep sles | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
    }
    upload_logs("/var/log/virt_dns_setup.log");
}

1;
