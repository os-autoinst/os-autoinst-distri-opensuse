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
#    assert_and_click('suma-salt-menu');
#    assert_and_click('suma-salt-formulas');
#    assert_and_click('suma-branch-network-formula-details');
#    assert_screen('suma-branch-network-formula-details-screen');
    assert_and_click('suma-systems-menu');
    assert_and_click('suma-systems-submenu');
    assert_and_click('suma-system-all');
    assert_and_click('suma-system-branch');
    assert_and_click('suma-system-formulas');
    assert_and_click('suma-system-formula-branch-network');
    assert_and_click('suma-system-formulas-save');
    assert_and_click('suma-system-formula-branch-network-tab');
    assert_and_click('suma-system-formula-branch-network-form');

    # nic
    send_key 'ctrl-a';
    type_string('eth1');send_key 'tab';
    # ip
    type_string('192.168.1.1');send_key 'tab'; # dns1.suse.cz for now, FIXME: dns on branch server
    # netmask
    type_string('255.255.0.0');send_key 'tab';
    assert_and_click('suma-system-formula-form-save');

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
    barrier_wait('branch_network_formula');
    barrier_wait('branch_network_formula_finish');
 
  }
}

1;
