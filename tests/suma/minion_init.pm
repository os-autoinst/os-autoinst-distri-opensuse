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
use utils 'zypper_call';
use lockapi;

sub run {
  my ($self) = @_;
  select_console 'root-console';

  my $id = get_var('HOSTNAME', 'minion') . '.openqa.suse.de';
  my $master = get_var('MASTER', 'master') . '.openqa.suse.de';

  assert_script_run("echo \"id: $id\" >> /etc/salt/minion");
  assert_script_run("echo \"master: $master\" >> /etc/salt/minion");

  assert_script_run("ping -c1 $master");
  script_run('ip a');
  script_run('zypper -n in dhcp-server');


  $self->check_and_add_repo();

  zypper_call('in POS_Image-JeOS6 kiwi kiwi-desc-netboot kiwi-desc-saltboot');


  barrier_wait('suma_master_ready');
  assert_script_run('systemctl restart salt-minion');
  barrier_wait('suma_minion_ready');
}

1;
