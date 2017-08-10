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
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    barrier_wait('pxe_formula');
    barrier_wait('pxe_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('pxe_formula');
    barrier_wait('pxe_formula_finish');
  }
  else {
    $self->install_formula('pxe-formula');

    my $driver = selenium_driver();

    $self->suma_menu('Salt', 'Formula Catalog');

    $driver->find_element('pxe', 'link_text')->click();
    wait_for_page_to_load;
    #FIXME: check formula details

    $self->suma_menu('Systems', 'Systems', 'All');

    $driver->find_element('suma-branch.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    $driver->find_element("//a[\@id='pxe']")->click();
    wait_for_page_to_load;
    $driver->find_element("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//li/a[.//text()[contains(., 'Pxe')]]")->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->mouse_move_to_location(element => $driver->find_element("//form[\@id='editFormulaForm']//input[1]"));
    $driver->double_click();
    save_screenshot;

    $driver->send_keys_to_active_element("linux");
    $driver->send_keys_to_active_element("\t");

    $driver->send_keys_to_active_element("initrd.gz");
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

    barrier_wait('pxe_formula');
    barrier_wait('pxe_formula_finish');
 
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
