# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Web configuration of SUSE Manager Server
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;

use utils 'zypper_call';

use selenium;

sub run {
  select_console('root-console');
  type_string "chown $username /dev/$serialdev\n";

  my $master = get_var('HOSTNAME');
  die "Error: variable HOSTNAME not defined." unless defined $master;

  add_chromium_repos;
  install_chromium;
  enable_selenium_port;

  select_console('x11');

  my $driver = selenium_driver();
  #$driver->debug_on;
  #$driver->set_implicit_wait_timeout(1);

  $driver->get('https://'.$master.'.openqa.suse.de');


#  if (check_screen('suma_ff_unknown_cert')) {
#    record_soft_failure('SUMA certificate not know to browser');
#    assert_and_click('suma_ff_advanced');
#    assert_and_click('suma_ff_add_exception');
#    assert_and_click('suma_ff_configm_exception');
#  }

  if ($driver->get_title() =~ /Sign In/) {
    $driver->find_element("//input[\@id='username-field']")->send_keys("admin");
    $driver->find_element("//input[\@id='password-field']")->send_keys($password);
    $driver->find_element("login", "id")->click();
  }

#  FIXME:
#  assert_screen(['suma_need_config', 'suma_welcome_screen', 'suma_login']);
#  if (match_has_tag('suma_need_config')) {
#    assert_and_click('suma_org_name_entry');
#    type_string('openQA');send_key('tab');
#    type_string('admin');send_key('tab');
#    type_password;send_key('tab');
#    type_password;send_key('tab');
#    type_string('susemanager@'.$master.'.openqa.suse.de');send_key('tab');
#    type_string('Mr');send_key('tab');
#    type_string('openQA');send_key('tab');
#    type_string('TestManager');send_key('tab');
#    assert_and_click('suma_create_org');
#    assert_and_click('suma_ff_store_credentials');
#    assert_screen('suma_welcome_screen');
#    if (get_var('SUMA_IMAGE_BUILD')) {
#      return 1;
#    }
#  }

  # turn off screensaver
  x11_start_program('xterm');
  assert_screen('xterm');
  script_run('gsettings set org.gnome.desktop.session idle-delay 0');
  send_key('ctrl-d');

  # allow minion to continue
  barrier_wait('suma_master_ready');
}

sub test_flags {
  return {fatal => 1}
}

1;
