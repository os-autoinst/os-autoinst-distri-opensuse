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
package proxymodeapi;
use strict;
use base "opensusebasetest";
use testapi;
use base "virt_autotest_base";

our $SLAVE_SERIALDEV = 'proxyserial';
our $DEBUG           = 1;

sub restart_host {
    my $self         = shift;
    my $ipmi_machine = get_var("IPMI_HOSTNAME");
    my $ipmitool     = "ipmitool -H " . $ipmi_machine . " -U ADMIN -P ADMIN ";
    $self->execute_script_run($ipmitool . 'chassis power off', 20);
    while (1) {
        my $stdout = $self->execute_script_run($ipmitool . 'chassis power status', 20);
        last if $stdout =~ m/is off/;
        script_run("", $ipmitool . 'chassis power off', 20);
        sleep(2);
    }

    $self->execute_script_run($ipmitool . 'chassis power on', 20);
    while (1) {
        my $ret = $self->execute_script_run($ipmitool . 'chassis power status', 20);
        last if $ret =~ m/is on/;
        $self->execute_script_run("", $ipmitool . 'chassis power on', 20);
        sleep(2);
    }

}

sub connect_slave {
    my $self = shift;
    script_run("clear");
    my $ipmi_machine = get_var("IPMI_HOSTNAME");
    #type_string("ipmitool -H 147.2.208.125 -U ADMIN -P ADMIN -I lanplus sol activate\n");
    type_string("ipmitool -H " . $ipmi_machine . " -U ADMIN -P ADMIN -I lanplus sol activate\n");
    send_key 'ret';
}

sub check_prompt_for_boot() {
    my $self    = shift;
    my $timeout = shift;
    if (!$timeout) {
        $timeout = 5000;
    }
    assert_screen("autoyast-system-login-console", $timeout);
    type_string "root\n";
    sleep 2;
    type_password;
    send_key "ret";
    assert_screen("text-logged-in-root", 10);
    type_string("clear;ip a\n");
}

sub save_org_serialdev() {
    my $self = shift;
    if (!get_var("PROXY_SERIALDEV")) {
        set_var("PROXY_SERIALDEV", $serialdev);
    }
}

sub get_org_serialdev() {
    my $self = shift;
    return get_var("PROXY_SERIALDEV", "ttyS0");
}

sub resume_org_serialdev() {
    my $self = shift;
    $serialdev = $self->get_org_serialdev();
}


sub set_curr_serialdev() {
    my $self = shift;
    $serialdev = $SLAVE_SERIALDEV;
}

sub create_nc() {
    my $self = shift;
    # Create nc connection on root console
    type_string "mkfifo /dev/$SLAVE_SERIALDEV\n";
    sleep 2;
    type_string "tail -f /dev/$SLAVE_SERIALDEV | nc -l 1234 &\n";
    save_screenshot;

    save_org_serialdev();
}

sub con_nc_from_tty() {
    my $self    = shift;
    my $console = shift;
    my $test_machine;

    if (!get_var("TEST_MACHINE")) {
        die "Failed to get test machine ip";
    }
    else {
        $test_machine = get_var("TEST_MACHINE");
    }
    if ($console) {
        select_console $console;
    }
    else {
        select_console 'log-console';
    }
    wait_still_screen(2);
    send_key "ctrl-c";
    send_key "ctrl-c";

    my $proxy_serialdev = get_var("PROXY_SERIALDEV", "ttyS0");

    if ($DEBUG) {
        type_string "#nc ${test_machine} 1234 |tee /dev/" . $proxy_serialdev . "\n";
    }

    type_string "nc ${test_machine} 1234 |tee /dev/" . $proxy_serialdev . "\n";
    sleep 3;
    save_screenshot;
}

sub back_pre_tty() {
    my $self = shift;
    # Back to previous console and prepare for next steps
    select_console "root-console";

    set_curr_serialdev();

    my $pattern = 'NC_CONNECTION_TEST-' . int(rand(999999));
    type_string "echo $pattern |tee /dev/$serialdev\n";
    if (!wait_serial($pattern, 10)) {
        die "Failed to build the connection between slave machine and proxy machine\n";
    }
    save_screenshot;
}

1;

