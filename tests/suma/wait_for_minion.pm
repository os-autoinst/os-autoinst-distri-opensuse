# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager Server
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;

sub run {
  send_key_until_needlematch('suma_pending_minions', 'ctrl-r', 10, 15);
  wait_screen_change {
    assert_and_click('suma_pending_minions');
  };
  send_key_until_needlematch('suma_salt_key_accept', 'right', 40, 1);
  wait_screen_change {
    assert_and_click('suma_salt_key_accept');
  };
  send_key_until_needlematch('suma-salt-minion-bootstrapped', 'ctrl-r', 10, 15);

  # create barriers for all loaded suma tests
  for my $t (@{get_var_array('SUMA_TESTS')}) {
    barrier_create($t, 3);
  }
  barrier_wait('suma_minion_ready');
}

1;
