# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager dhcpd salt formula
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use selenium;

sub run {
    my ($self) = @_;
    if (check_var('SUMA_SALT_MINION', 'branch')) {
        # barriers for salt terminal(s)
        my $n = keys get_children();
        barrier_create('dhcp_ready', $n + 1);
        $self->register_barriers('dhcpd_formula', 'dhcp_ready', 'dhcpd_formula_finish');

        assert_script_run 'ip addr';
        $self->registered_barrier_wait('dhcpd_formula');

        # minion test
        assert_script_run('systemctl is-active dhcpd.service');
        # TODO check files are proper
        # allow salt terminal to continue
        $self->registered_barrier_wait('dhcp_ready');
        # and wait for it to finish, and allow salt master to continue
        $self->registered_barrier_wait('dhcpd_formula_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        $self->register_barriers('dhcpd_formula', 'dhcp_ready', 'dhcpd_formula_finish');
        $self->registered_barrier_wait('dhcpd_formula');
        $self->registered_barrier_wait('dhcp_ready');
        assert_script_run('/usr/lib/wicked/bin/wickedd-dhcp4 --test eth0');
        assert_script_run "echo \"STARTMODE='auto'\nBOOTPROTO='dhcp4'\n'\" > /etc/sysconfig/network/ifcfg-eth0";
        assert_script_run 'systemctl restart network';
        assert_script_run 'ifup eth0';
        assert_script_run 'ip addr';

        $self->registered_barrier_wait('dhcpd_formula_finish');
    }
    else {
        $self->register_barriers('dhcpd_formula', 'dhcpd_formula_finish');
        $self->install_formula('dhcpd-formula');
        $self->select_formula('dhcpd', 'Dhcpd');


        my $driver = selenium_driver();
        $driver->mouse_move_to_location(element => wait_for_xpath("//form[\@id='editFormulaForm']//input[1]"));
        $driver->double_click();
        save_screenshot;
        # domain
        $driver->send_keys_to_active_element('internal.suma.openqa.suse.de');
        $driver->send_keys_to_active_element("\t");
        # dns servers
        $driver->send_keys_to_active_element('192.168.1.1');
        $driver->send_keys_to_active_element("\t");
        # device
        $driver->send_keys_to_active_element('eth1');
        $driver->send_keys_to_active_element("\t");
        # skip leases
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element("\t");
        # network
        $driver->send_keys_to_active_element('192.168.0.0');
        $driver->send_keys_to_active_element("\t");
        # netmask
        $driver->send_keys_to_active_element('255.255.0.0');
        $driver->send_keys_to_active_element("\t");
        # dhcp range
        $driver->send_keys_to_active_element('192.168.242.51,192.168.243.151');
        $driver->send_keys_to_active_element("\t");
        # broadcast
        $driver->send_keys_to_active_element('192.168.255.255');
        $driver->send_keys_to_active_element("\t");
        # routers
        $driver->send_keys_to_active_element('192.168.1.1');
        $driver->send_keys_to_active_element("\t");
        # next server
        $driver->send_keys_to_active_element('192.168.1.1');
        $driver->send_keys_to_active_element("\t");
        # pxe filename
        $driver->send_keys_to_active_element('/boot/pxelinux.0');
        $driver->send_keys_to_active_element("\t");

        save_screenshot;
        wait_for_xpath("//button[\@id='save-btn']")->click();

        $self->apply_highstate();

        # signal minion to check configuration
        $self->registered_barrier_wait('dhcpd_formula');
        $self->registered_barrier_wait('dhcpd_formula_finish');
    }
}

sub test_flags() {
    return {milestone => 1};
}

1;
