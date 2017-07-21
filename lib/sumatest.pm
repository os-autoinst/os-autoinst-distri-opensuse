# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager Server
# Maintainer: Ondrej Holecek <oholecek@suse.com>

package sumatest;
use parent "x11test";

use 5.018;
use testapi;
use utils 'zypper_call';
use mm_network;

sub post_fail_hook() {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->export_suma_logs;
    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;
    if (check_var('DESKTOP', 'textmode')) {
      # start next test in home directory
      type_string "cd\n";
      # clear screen to make screen content ready for next test
      $self->clear_and_verify_console;
    }
    else {
      assert_and_click('suma_go_home');
      assert_screen('suma_welcome_screen');
    }
}

sub export_suma_logs {
    my ($self) = @_;
    select_console 'root-console';
    script_run '/usr/bin/spacewalk-debug';
    upload_logs '/tmp/spacewalk-debug.tar.bz2';
}

sub check_and_add_repo {
  my ($self) = @_;
  my $SUMA_FORMULA_REPO = get_var('SUMA_FORMULA_REPO', 'http://download.suse.de/ibs/Devel:/SLEPOS:/SUSE-Manager-Retail:/Head/SLE_12_SP2/');
  die 'Missing SUMA_FORMULA_REPO variable with formulas installation repository' unless $SUMA_FORMULA_REPO;

  my $ret = zypper_call("lr SUMA_REPO", exitcode => [0,6]);
  if ($ret == 6) {
    zypper_call("ar -c -f -G $SUMA_FORMULA_REPO SUMA_REPO");
    zypper_call("--gpg-auto-import-keys ref");
  }
}

sub install_formula {
  my ($self, $formula) = @_;

  select_console 'root-console';
  $self->check_and_add_repo();
  zypper_call("in $formula");
  select_console 'x11', tags => 'suma_welcome_screen';
  assert_and_click('suma_go_home');
  assert_screen('suma_welcome_screen');
}

sub configure_networks {
  my ($self, $ip, $hostname) = @_;

  configure_default_gateway();
  configure_static_ip("$ip/24");
  configure_static_dns(get_host_resolv_conf());

  # set working hostname -f
  assert_script_run "echo \"$ip $hostname.openqa.suse.de $hostname\" >> /etc/hosts";
  assert_script_run 'cat /etc/hosts';
  assert_script_run "hostname -f|grep $hostname";
}

1;
# vim: set sw=4 et:
