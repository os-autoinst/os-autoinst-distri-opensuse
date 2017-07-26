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

use base "consoletest";
use 5.018;
use testapi;
use utils 'zypper_call';
use lockapi;
use mm_network;

sub run {
  my ($self) = @_;
  select_console 'root-console';
  configure_dhcp();
  script_run('ip a');
}

1;
