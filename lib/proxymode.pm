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

use base 'basetest';
use testapi;
use strict;

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
    wait_idle 10;
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
    sleep 2;
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
    sleep 3;
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
1;

