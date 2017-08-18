# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of Branch Server Network formula
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use selenium;

sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    barrier_wait('branch_network_formula');
    assert_script_run('ip a');
    assert_script_run('ip a | grep 192.168.1.1');
    assert_script_run('grep "^FW_DEV_INT=.*eth1" /etc/sysconfig/SuSEfirewall2');
    assert_script_run('grep "^FW_ROUTE=.*yes" /etc/sysconfig/SuSEfirewall2');
    barrier_wait('branch_network_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('branch_network_formula');
    barrier_wait('branch_network_formula_finish');
  }
  else {
    $self->install_formula('branch-network-formula');
    $self->select_formula('branch-network','Branch Network');
    
    my $driver = selenium_driver();
    $driver->mouse_move_to_location(element => $driver->find_element("//form[\@id='editFormulaForm']//input[1]"));
    $driver->double_click();
    save_screenshot;
    # nic
    $driver->send_keys_to_active_element('eth1');
    $driver->send_keys_to_active_element("\t");
    # ip

    $driver->send_keys_to_active_element('192.168.1.1');
    $driver->send_keys_to_active_element("\t");

    # netmask
    $driver->send_keys_to_active_element('255.255.0.0');
    $driver->send_keys_to_active_element("\t");
    save_screenshot;
    $driver->find_element("//button[\@id='save-btn']")->click();

    
    $self->apply_highstate();

    barrier_wait('branch_network_formula');
    barrier_wait('branch_network_formula_finish');

  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
