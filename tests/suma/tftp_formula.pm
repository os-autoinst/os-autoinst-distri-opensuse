# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager tftp salt formula
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use selenium;

sub run {
  my ($self) = @_;
  
  #TODO: get from common module / branch network test to ensure compatibility
  my $testip = '192.168.1.1';
  
  if (check_var('SUMA_SALT_MINION', 'branch')) {
 
    #need to create after tftp_formula barrier is breached, or creation will be too early    
    my $bn= keys get_children();
    barrier_create('tftp_ready', $bn+1);  

    # configure second interface for tftp
    barrier_wait('tftp_formula');
    
    # minion test
    script_run('systemctl status atftpd.service');
    assert_script_run('systemctl is-active atftpd.service');

    script_run('cat /etc/sysconfig/atftpd | grep -P -v \'^(\s*$|^#)\'');
    assert_script_run('cat /etc/sysconfig/atftpd | grep \'ATFTPD_BIND_ADDRESSES="'.$testip.'"\''); 

    #test tftp listening on udp port 69
    #TODO: remove softfail after bug is fixed
    script_run('netstat -uplne'); 
    if ( script_run('netstat -ulnp | grep \''.$testip.':69\s\' | grep -P \'/atftpd\s*$\' ') ) {
      record_soft_failure('atftpd listens everywhere: bsc#1049832');
    }
    
    script_run('echo "test" > /srv/tftpboot/test');
    type_string('atftp localhost');send_key('ret');
    type_string('get test');send_key('ret');
    type_string('quit');send_key('ret');
    assert_script_run('diff test /srv/tftpboot/test'); 

    save_screenshot;
    
    barrier_wait('tftp_ready');  
    barrier_wait('tftp_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('tftp_formula');
    barrier_wait('tftp_ready');  

    script_run('echo "test" > /tmp/test2cmp');
    type_string('atftp '.$testip);send_key('ret');
    type_string('get test');send_key('ret');
    type_string('quit');send_key('ret');
    assert_script_run('diff test /tmp/test2cmp'); 
      
    barrier_wait('tftp_formula_finish');
  }
  else {

    my $master = get_var('HOSTNAME');#exists, checked in webinit

    $self->install_formula('tftp-formula');

    my $driver = selenium_driver();

    $self->suma_menu('Salt', 'Formula Catalog');

    $driver->find_element('tftp', 'link_text')->click();
    wait_for_page_to_load;
    #FIXME: check formula details

    $self->suma_menu('Systems', 'Systems', 'All');

    $driver->find_element('suma-branch.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('Formulas', 'link_text')->click();
    wait_for_page_to_load;
    $driver->find_element("//a[\@id='tftp']")->click();
    wait_for_page_to_load;
    $driver->find_element("//button[\@id='save-btn']")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//li/a[.//text()[contains(., 'Tftp')]]")->click();
    wait_for_page_to_load;
    save_screenshot;

    $driver->mouse_move_to_location(element => $driver->find_element("//form[\@id='editFormulaForm']//input[1]"));
    $driver->double_click();
    save_screenshot;
    # ip

    $driver->send_keys_to_active_element($testip);
    $driver->send_keys_to_active_element("\t");

    save_screenshot;
    $driver->find_element("//button[\@id='save-btn']")->click();

    # apply high state
    $driver->find_element('States', 'link_text')->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element("//button[.//text()[contains(., 'Apply Highstate')]]")->click();
    wait_for_page_to_load;
    save_screenshot;
    $driver->find_element('scheduled', 'partial_link_text')->click();
    wait_for_page_to_load;
    wait_for_link("1 system", 10, 15)->click();

    $driver->find_element('suma-branch.openqa.suse.de', 'link_text')->click();
    wait_for_page_to_load;

    # check for success
    die "Highstate failed" unless wait_for_text("Successfully applied state", 10, 15);

    # signal minion to check configuration
    barrier_wait('tftp_formula');
    barrier_wait('tftp_formula_finish');
  }
}

sub test_flags() {
    return {milestone => 1};
}

1;
