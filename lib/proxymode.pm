# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package proxymode;
# Summary: proxymode: The basic lib for using proxy mode to connect or operation with physical machine
# Maintainer: John <xgwang@suse.com>

use base 'y2logsstep';
use testapi;
use strict;
use warnings;

our $SLAVE_SERIALDEV = 'proxyserial';

sub switch_power {
    my ($ipmi_machine, $ipmi_user, $ipmi_pass, $ipmi_status) = @_;
    $ipmi_pass   //= 'ADMIN';
    $ipmi_user   //= 'ADMIN';
    $ipmi_status //= 'off';
    die "Variable ipmi_machine is invalid in function restart_host!" unless $ipmi_machine;
    my $ipmitool = "ipmitool -H " . $ipmi_machine . " -U " . $ipmi_user . " -P " . $ipmi_pass . " -I lanplus ";
    script_run($ipmitool . 'chassis power ' . $ipmi_status, 20);
    while (1) {
        my $stdout = script_output($ipmitool . 'chassis power status', 20);
        last if $stdout =~ m/is $ipmi_status/;
        die "Failure on running IPMITOOL:" . $stdout if $stdout =~ m/Error/;
        script_run($ipmitool . 'chassis power ' . $ipmi_status, 20);
        sleep(2);
    }
}

sub restart_host {
    my ($self, $ipmi_machine, $ipmi_user, $ipmi_pass) = @_;
    select_console 'log-console';
    switch_power($ipmi_machine, $ipmi_user, $ipmi_pass, 'off');
    switch_power($ipmi_machine, $ipmi_user, $ipmi_pass, 'on');
    wait_still_screen 10;
    save_screenshot;
    select_console 'root-console';
}

sub connect_slave {
    my ($self, $ipmi_machine, $ipmi_user, $ipmi_pass) = @_;
    $ipmi_user //= 'ADMIN';
    $ipmi_pass //= 'ADMIN';
    die "Variable ipmi_machine is invalid in function connect_slave!" unless $ipmi_machine;
    script_run("clear");
    type_string("ipmitool -H " . $ipmi_machine . " -U " . $ipmi_user . " -P " . $ipmi_pass . " -I lanplus sol activate", 20);
    send_key 'ret';
    send_key 'ret';
    save_screenshot;
}

sub check_prompt_for_boot {
    my ($self, $timeout) = @_;
    $timeout //= 5000;
    assert_screen("autoyast-system-login-console", $timeout);
    type_string "root\n";
    wait_still_screen(2);
    type_password;
    send_key "ret";
    assert_screen("text-logged-in-root");
    type_string("clear;ip a\n");
}

sub save_org_serialdev {
    if (!get_var("PROXY_SERIALDEV")) {
        set_var("PROXY_SERIALDEV", $serialdev);
    }
}

sub get_org_serialdev {
    return get_var("PROXY_SERIALDEV", "ttyS0");
}

sub resume_org_serialdev {
    $serialdev = get_org_serialdev();
}

sub set_serialdev {
    $serialdev = $SLAVE_SERIALDEV;
}

sub start_nc_on_slave {
    my ($self) = @_;
    # Create nc connection on root console
    type_string "mkfifo /dev/$SLAVE_SERIALDEV\n";
    type_string "tail -f /dev/$SLAVE_SERIALDEV | nc -l 1234 &\n";
    save_screenshot;
    save_org_serialdev();
}

sub con_nc_on_proxy {
    my ($self, $test_machine, $console) = @_;
    wait_still_screen(2);
    send_key "ctrl-c";
    send_key "ctrl-c";

    my $proxy_serialdev = get_var("PROXY_SERIALDEV", "ttyS0");

    type_string "nc ${test_machine} 1234 |tee /dev/" . $proxy_serialdev . "\n";
    save_screenshot;
}

sub reset_curr_serialdev {
    my ($self) = @_;
    set_serialdev();
    my $pattern = 'NC_CONNECTION_TEST-' . int(rand(999999));
    type_string "echo $pattern |tee /dev/$serialdev\n";
    die "Failed to build the connection between slave machine and proxy machine!" unless wait_serial($pattern, 10);
    save_screenshot;
}

sub redirect_serial {
    my ($self, $test_machine) = @_;
    die "The variable test_machine should not be empty!" unless $test_machine;
    $self->start_nc_on_slave();
    select_console 'log-console';
    $self->con_nc_on_proxy($test_machine);
    select_console "root-console";
    $self->reset_curr_serialdev();
}

sub get_consoledev {
    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        script_run("clear");
        my $prd_version = script_output("cat /etc/os-release");
        save_screenshot;
        $prd_version =~ /.*VERSION\s*=\s*\"(\d+)-SP(\d+)\"/sm;
        my ($main_version, $patch_level) = ($1, $2);
        if ($main_version > 12 || ($main_version == 12 && $patch_level >= 2)) {
            return "hvc0";
        }
        else {
            return "xvc0";
        }
    }
    else {
        return "ttyS1";
    }
}

sub generate_grub {
    my ($self) = @_;
    my $ipmi_console = get_consoledev();
    #only support grub2
    my $grub_default_file = "/etc/default/grub";
    my $grub_cfg_file     = "/boot/grub2/grub.cfg";

    my $cmd
      = "if [ -d /boot/grub2 ]; then cp $grub_default_file ${grub_default_file}.org; sed -ri '/GRUB_CMDLINE_(LINUX|LINUX_DEFAULT|XEN_DEFAULT)=/ {s/(console|com\\d+|loglevel|log_lvl|guest_loglvl)=[^ \"]*//g; /LINUX=/s/\"\$/ loglevel=5 console=$ipmi_console,115200 console=tty\"/;/XEN_DEFAULT=/ s/\"\$/ log_lvl=all guest_loglvl=all console=com2,115200\"/;}' $grub_default_file ; fi";
    script_run("$cmd");
    wait_still_screen 3;
    save_screenshot;
    script_run("clear; cat $grub_default_file");
    wait_still_screen 3;
    save_screenshot;

    $cmd = "if [ -d /boot/grub2 ]; then grub2-mkconfig -o $grub_cfg_file; fi";
    script_run("$cmd", 40);
    wait_still_screen 3;
    save_screenshot;
    script_run("clear; cat $grub_cfg_file");
    wait_still_screen 3;
    save_screenshot;
}

sub set_default_boot_sequence {
    my ($self, $hypervisor) = @_;
    # Set default boot order only for xen hypervisor
    if ($hypervisor eq 'xen') {
        my $cmd
          = "grub=`find /boot/ -name grub.cfg -o -name menu.list`;echo \$grub;index=`grep -iE '^menuentry\|^submenu\|^title' \$grub|grep -ni 'xen'|head -1|awk -F: '{print \$1-1}'`;echo \$index;if [ \$index -ge 0 ];then if [[ \$grub = *\"grub.cfg\"* ]];then echo \$index;grub2-set-default \$index; else sed -i \"s/^default .*/default \$index/;s/set default=.*/set default=\$index/\" \$grub; fi; else echo \"There is no xen boot options\"; fi";
        script_run("$cmd");
        wait_still_screen 3;
        save_screenshot;
    }
}

sub reboot {
    my ($self, $test_machine, $timeout) = @_;
    # Wrap multiple function as one
    $timeout //= 300;
    die "Variable test_machine is invalid for reboot!" unless $timeout;
    $self->generate_grub();
    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        $self->set_default_boot_sequence("xen");
    }
    type_string("/sbin/reboot\n");
    $self->check_prompt_for_boot($timeout);
    $self->redirect_serial($test_machine);
}

1;
