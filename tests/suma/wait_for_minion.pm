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
use selenium;

sub run {
  my ($self) = @_;  
  my $driver = selenium_driver();
  $self->register_barriers('suma_minion_ready');

  wait_for_link("Pending Minions", -tries => 10, -wait => 15, -reload_after_tries => 1)->click();
  wait_for_xpath("//button[\@title='accept']")->click();

  wait_for_link(".openqa.suse.de", -tries => 10, -wait => 15, -reload_after_tries => 1)->click();

  save_screenshot;

  $self->apply_highstate();

  $self->registered_barrier_wait('suma_minion_ready');
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
