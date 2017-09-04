# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager pxe salt formula
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use selenium;

sub run {
  my ($self) = @_;
  $self->register_barriers('pxe_formula', 'pxe_formula_finish');
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    $self->registered_barrier_wait('pxe_formula');
    $self->registered_barrier_wait('pxe_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    $self->registered_barrier_wait('pxe_formula');
    $self->registered_barrier_wait('pxe_formula_finish');
  }
  else {
    $self->install_formula('pxe-formula');
    $self->select_formula('pxe','Pxe');

    my $driver = selenium_driver();
    $driver->mouse_move_to_location(element => wait_for_xpath("//form[\@id='editFormulaForm']//input[1]"));
    $driver->double_click();
    save_screenshot;

    $driver->send_keys_to_active_element("linux");
    $driver->send_keys_to_active_element("\t");

    $driver->send_keys_to_active_element("initrd.gz");
    $driver->send_keys_to_active_element("\t");

    save_screenshot;
    wait_for_xpath("//button[\@id='save-btn']")->click();
    
    $self->apply_highstate();

    $self->registered_barrier_wait('pxe_formula');
    $self->registered_barrier_wait('pxe_formula_finish');
 
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
