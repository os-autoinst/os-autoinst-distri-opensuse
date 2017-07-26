# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create basic barrier locks
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use 5.018;
use parent "basetest";
use lockapi;
use mmapi;
use testapi;

sub run {
  # this is for master to wait for minion-branchserver
  barrier_create('suma_minion_ready', 2);
  # this is for minion to wait for master
  barrier_create('suma_master_ready', 2);

  my $n = keys get_children();

  # create barriers for all loaded suma tests
  for my $t (@{get_var_array('SUMA_TESTS')}) {
    barrier_create($t, $n+1);
    barrier_create($t.'_finish', $n+1);
  }
  
}

sub test_flags {
  return {fatal => 1}
}

1;
