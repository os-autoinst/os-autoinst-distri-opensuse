# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager saltboot formula
# # Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use selenium;

sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    barrier_wait('saltboot_formula');
    barrier_wait('saltboot_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('saltboot_formula');
    barrier_wait('saltboot_formula_finish');
  }
  else {
    $self->install_formula('saltboot-formula');

    select_console 'root-console';

    # fix api password
    type_string 'sed -i -e "s|MANAGER_PASSWORD = .*|MANAGER_PASSWORD = \''; type_password ; type_string '\'|" /usr/share/susemanager/modules/runners/registration.py' . "\n";
    assert_script_run 'systemctl restart salt-master'; # because of reactors installed
    select_console 'x11', tags => 'suma_welcome_screen';

    my $driver = selenium_driver();

    $self->suma_menu('Salt', 'Formula Catalog');

    $driver->find_element('saltboot', 'link_text')->click();
    wait_for_page_to_load;
    #FIXME: check formula details

    $self->suma_menu('Systems', 'System Groups');

    $driver->find_element('Create Group', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->mouse_move_to_location(element => $driver->find_element("//input[\@id='name']"));
    $driver->double_click();

    $driver->send_keys_to_active_element('hwtype_testterm');
    $driver->send_keys_to_active_element("\t");

    $driver->send_keys_to_active_element('group for testterm hwtype');
    $driver->send_keys_to_active_element("\t");

    save_screenshot;

    $driver->find_element("//input[\@value='Create Group']")->click();
    wait_for_page_to_load;


    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    $driver->find_element("//a[\@id='saltboot']")->click();
    wait_for_page_to_load;
    $driver->find_element("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//li/a[.//text()[contains(., 'Saltboot')]]")->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->mouse_move_to_location(element => $driver->find_element("//form[\@id='editFormulaForm']//input[1]"));
    $driver->double_click();
    save_screenshot;

    # FIXME: fill in form data
    save_screenshot;
    $driver->find_element("//button[\@id='save-btn']")->click();

    wait_for_page_to_load;
    save_screenshot;

    # signal minion to check configuration
    barrier_wait('saltboot_formula');
    barrier_wait('saltboot_formula_finish');
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
