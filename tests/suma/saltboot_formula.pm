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
    barrier_create('saltboot_formula_finish', 3);
    $self->install_formula('saltboot-formula');

    select_console 'root-console';

    # fix api password
    type_string 'sed -i -e "s|MANAGER_PASSWORD = .*|MANAGER_PASSWORD = \''; type_password ; type_string '\'|" /usr/share/susemanager/modules/runners/registration.py' . "\n";
    assert_script_run 'systemctl restart salt-master'; # because of reactors installed
    select_console 'x11', tags => 'suma_welcome_screen';

#    assert_and_click('suma-salt-menu');
#    assert_and_click('suma-salt-formulas');
#    assert_and_click('suma-saltboot-formula-details');
#    assert_screen('suma-saltboot-formula-details-screen');
    assert_and_click('suma-systems-menu');
    assert_and_click('suma-system-groups-submenu');
    assert_and_click('suma-create-group');
    assert_and_click('suma-create-group-form');
    type_string('hwtype_testterm');send_key 'tab';
    type_string('group for testterm hwtype');
    assert_and_click('suma-create-group-button');

    assert_and_click('suma-group-formulas');
    assert_and_click('suma-group-formula-saltboot');
    assert_and_click('suma-group-formulas-save');
    assert_and_click('suma-group-formula-saltboot-tab');

    # signal minion to check configuration
    barrier_wait('saltboot_formula');
    barrier_wait('saltboot_formula_finish');
  }
}

1;
