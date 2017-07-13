# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test boot of a terminal
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use utils 'zypper_call';


sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    barrier_wait('saltboot_orchestrate');
    sleep 1000;
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    select_console 'root-console';
    barrier_wait('saltboot_orchestrate');
    type_string "shutdown -r now\n";
    sleep 1000;
  }
  else {
    barrier_wait('saltboot_orchestrate');
    send_key_until_needlematch('suma_pending_minions', 'ctrl-r', 50, 5);
    wait_screen_change {
      assert_and_click('suma_pending_minions');
    };
    send_key_until_needlematch('suma_salt_key_accept', 'right', 40, 1);
    wait_screen_change {
      assert_and_click('suma_salt_key_accept');
    };
    sleep 1000;
  }
}

1;
