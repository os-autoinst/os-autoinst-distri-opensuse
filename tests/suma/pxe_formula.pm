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
#    assert_and_click('suma-salt-menu');
#    assert_and_click('suma-salt-formulas');
#    assert_and_click('suma-pxe-formula-details');
#    assert_screen('suma-pxe-formula-details-screen');
    assert_and_click('suma-systems-menu');
    assert_and_click('suma-systems-submenu');
    assert_and_click('suma-system-all');
    assert_and_click('suma-system-branch');
    assert_and_click('suma-system-formulas');
    assert_and_click('suma-system-formula-pxe');
    assert_and_click('suma-system-formulas-save');
#    assert_and_click('suma-system-formula-pxe-tab');

    # apply high state
    assert_and_click('suma-system-formulas');
    assert_and_click('suma-system-formula-highstate');
    wait_screen_change {
      assert_and_click('suma-system-formula-event');
    };
    # wait for high state
    # check for success
    send_key_until_needlematch('suma-system-highstate-finish', 'ctrl-r');
    wait_screen_change {
      assert_and_click('suma-system-highstate-finish');
    };
    send_key_until_needlematch('suma-system-highstate-success', 'pgdn');
    barrier_wait('pxe_formula');
    barrier_wait('pxe_formula_finish');
 
  }
}

1;
