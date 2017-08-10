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
    barrier_create('dhcp_ready', $n+1);

    assert_script_run 'ip addr';
    barrier_wait('dhcpd_formula');

    # minion test
    assert_script_run('systemctl is-active dhcpd.service');
    # TODO check files are proper
    # allow salt terminal to continue
    barrier_wait('dhcp_ready');
    # and wait for it to finish, and allow salt master to continue
    barrier_wait('dhcpd_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('dhcpd_formula');
    barrier_wait('dhcp_ready');
    assert_script_run('/usr/lib/wicked/bin/wickedd-dhcp4 --test eth0');
    assert_script_run "echo \"STARTMODE='auto'\nBOOTPROTO='dhcp4'\n'\" > /etc/sysconfig/network/ifcfg-eth0";
    assert_script_run 'systemctl restart network';
    assert_script_run 'ifup eth0';
    assert_script_run 'ip addr';

    barrier_wait('dhcpd_formula_finish');
  }
  else {
    $self->install_formula('dhcpd-formula');

    my $driver = selenium_driver();

    $self->suma_menu('Salt', 'Formula Catalog');

    $driver->find_element('dhcpd', 'link_text')->click();
    wait_for_page_to_load;
    #FIXME: check formula details

    $self->suma_menu('Systems', 'Systems', 'All');

    $driver->find_element('suma-branch.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    $driver->find_element("//a[\@id='dhcpd']")->click();
    wait_for_page_to_load;
    $driver->find_element("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//li/a[.//text()[contains(., 'Dhcpd')]]")->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->mouse_move_to_location(element => $driver->find_element("//form[\@id='editFormulaForm']//input[1]"));
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
    $driver->find_element("//button[\@id='save-btn']")->click();

    # apply high state
    $driver->find_element('States', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//button[.//text()[contains(., 'Apply Highstate')]]")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('scheduled', 'partial_link_text')->click();
    wait_for_page_to_load;
    wait_for_link("1 system", 10, 15)->click();

    $driver->find_element('suma-branch.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;

    # check for success
    die "Highstate failed" unless wait_for_text("Successfully applied state", 10, 15);

    # signal minion to check configuration
    barrier_wait('dhcpd_formula');
    barrier_wait('dhcpd_formula_finish');
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
