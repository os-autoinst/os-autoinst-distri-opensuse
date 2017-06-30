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
use mm_network;

sub run {
  my ($self) = @_;
  select_console 'root-console';

  my $ip = '10.0.2.11';
  my $hostname = get_var('HOSTNAME', 'minion');
  my $master_ip = '10.0.2.10';
  my $master = get_var('MASTER', 'master');

  configure_default_gateway();
  configure_static_ip("$ip/24");
  configure_static_dns(get_host_resolv_conf());
  configure_hostname($hostname);
  # set working hostname -f and resolvable master
  assert_script_run "echo \"$ip $hostname.openqa.suse.de $hostname\" >> /etc/hosts";
  assert_script_run "echo \"$master_ip $master.openqa.suse.de $master\" >> /etc/hosts";
  assert_script_run 'cat /etc/hosts';
  assert_script_run "hostname -f|grep $hostname";


  zypper_call('in salt-minion');
}

1;
