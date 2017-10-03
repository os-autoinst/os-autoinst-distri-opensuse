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
use mmapi;
use selenium;

sub create_group_for_hwtype {
  my $self = shift;
  my $hwtype = shift;

  my $driver = selenium_driver();

  $self->suma_menu('Salt', 'Formula Catalog');

  wait_for_link('saltboot')->click();
  wait_for_page_to_load;
  #FIXME: check formula details

  $self->suma_menu('Systems', 'System Groups');

  wait_for_link('Create Group')->click();
  wait_for_page_to_load;
  save_screenshot;

  $driver->mouse_move_to_location(element => wait_for_xpath("//input[\@id='name']"));
  $driver->double_click();

  $driver->send_keys_to_active_element("hwtype_$hwtype");
  $driver->send_keys_to_active_element("\t");

  $driver->send_keys_to_active_element("group for $hwtype hwtype");
  $driver->send_keys_to_active_element("\t");

  save_screenshot;

  wait_for_xpath("//input[\@value='Create Group']")->click();
  wait_for_page_to_load;


  $driver->find_element('Formulas', 'link_text')->click();
  wait_for_page_to_load;
  wait_for_xpath("//a[\@id='saltboot']")->click();
  wait_for_page_to_load;
  wait_for_xpath("//button[\@id='save-btn']")->click();
  wait_for_page_to_load;
  save_screenshot;
  sleep 1;
  wait_for_xpath("//li/a[.//text()[contains(., 'Saltboot')]]", -tries => 15, -wait => 2)->click();
  wait_for_page_to_load;
  save_screenshot;

  $driver->mouse_move_to_location(element => wait_for_xpath("//form[\@id='editFormulaForm']//input[1]"));
  $driver->double_click();
  save_screenshot;

  # FIXME: fill in form data
  save_screenshot;
  wait_for_xpath("//button[\@id='save-btn']")->click();

  wait_for_page_to_load;
  save_screenshot;
}


sub run {
  my ($self) = @_;
  $self->register_barriers('saltboot_formula', 'saltboot_formula_finish');
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    $self->registered_barrier_wait('saltboot_formula');
    $self->registered_barrier_wait('saltboot_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    $self->registered_barrier_wait('saltboot_formula');
    $self->registered_barrier_wait('saltboot_formula_finish');
  }
  else {
    $self->install_formula('saltboot-formula');

    select_console 'root-console';

    # fix api password
    type_string 'sed -i -e "s|MANAGER_PASSWORD = .*|MANAGER_PASSWORD = \''; type_password ; type_string '\'|" /usr/share/susemanager/modules/runners/registration.py' . "\n";
    assert_script_run 'systemctl restart salt-master'; # because of reactors installed
    select_console 'x11', tags => 'suma_welcome_screen';

    my %hwtypes = ('testterm' => 1);

    for my $hwtype ($self->get_hwtypes) {
      $self->create_group_for_hwtype($hwtype);
    }

    # signal minion to check configuration
    $self->registered_barrier_wait('saltboot_formula');
    $self->registered_barrier_wait('saltboot_formula_finish');
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
