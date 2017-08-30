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
use selenium;

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
      save_screenshot;
      my $driver = selenium_driver();
      $driver->find_element("//a[\@href='/']")->click();
      wait_for_page_to_load;
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
  my $driver = selenium_driver();
  $driver->find_element("//a[\@href='/']")->click();
  wait_for_page_to_load;
}

sub select_formula {
    my ($self, $formula, $formula_name) = @_;        
    my $driver = selenium_driver();

    $self->suma_menu('Salt', 'Formula Catalog');
    $driver->find_element($formula, 'link_text')->click();
    wait_for_page_to_load;
    #FIXME: check formula details
    $self->suma_menu('Systems', 'Systems', 'All');

    $driver->find_element( get_var('BRANCH_HOSTNAME').'.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    wait_for_xpath("//a[\@id='$formula']", -tries => 5, -wait => 10)->click();
    wait_for_page_to_load;
    save_screenshot;
    wait_for_xpath("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    save_screenshot;
    sleep 1;
    wait_for_xpath("//li/a[.//text()[contains(., '$formula_name')]]", -tries => 15, -wait => 3, -reload_after_tries => 3)->click();
    wait_for_page_to_load;
    save_screenshot;
}

sub apply_highstate {
    my ($self) = @_;
    my $driver = selenium_driver();
    wait_for_page_to_load;
    # apply high state
    $driver->find_element('States', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;

    wait_for_xpath("//button[.//text()[contains(., 'Apply Highstate')]]")->click();
    wait_for_page_to_load;
    save_screenshot;
    wait_for_link('scheduled', -tries => 30, -wait => 5, -reload_after_tries => 3)->click();
    save_screenshot;
    wait_for_page_to_load;
    save_screenshot;
    wait_for_link("1 system", -tries => 30, -wait => 5, -reload_after_tries => 3)->click();
    save_screenshot;
 
    $driver->find_element( get_var('BRANCH_HOSTNAME').'.openqa.suse.de', 'link_text')->click();
    save_screenshot;
    wait_for_page_to_load;

    # check for success
    die "Highstate failed" unless wait_for_text("Successfully applied state", -tries => 10, -wait => 15);
    
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

sub suma_menu {
  my $self = shift;
  my $entry = shift;

  my $driver = selenium_driver();

  my $entry_elem = wait_for_xpath("//a[.//text()[contains(., '$entry')]]");
  $entry_elem->click();
  wait_for_page_to_load;

  while ($entry = shift) {
    $entry_elem = $driver->find_child_element($entry_elem, "./ancestor::ul//ul//a[.//text()[contains(., '$entry')]]");
    $entry_elem->click();
    wait_for_page_to_load;
  }
}


1;
# vim: set sw=4 et:
