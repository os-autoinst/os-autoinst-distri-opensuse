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

sub run {
  my ($self) = @_;
  
  #TODO: get from common module / branch network test to ensure compatibility
  my $testip = '192.168.1.1';

  if (check_var('SUMA_SALT_MINION', 'branch')) {
    # configure second interface for tftp
    assert_script_run 'systemctl stop SuSEfirewall2';
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
    
    barrier_wait('tftp_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('tftp_formula');
    barrier_wait('tftp_formula_finish');
  }
  else {
            
    my $master = get_var('HOSTNAME');#exists, checked in webinit

    $self->install_formula('tftp-formula');
    
    wait_still_screen; 
    send_key 'ctrl-l';
    type_string('https://'.$master.'.openqa.suse.de/rhn/manager/formula-catalog');send_key('ret');
    
    assert_and_click('suma-tftp-formula-details');
    assert_screen('suma-tftp-formula-details-screen');

    #goto first system formula details
    wait_still_screen;     
    send_key 'ctrl-l';
    type_string('https://'.$master.'.openqa.suse.de/rhn/manager/systems/details/formulas?sid=1000010000');send_key('ret');

    send_key_until_needlematch('suma-system-formula-tftp', 'down', 40, 1);
    assert_and_click('suma-system-formula-tftp');
    assert_and_click('suma-system-formulas-save');
    assert_and_click('suma-system-formula-tftp-tab');
    # fill in form details
    assert_and_click('suma-system-formula-tftp-form');
    # tftp ip
    send_key 'shift-home';
    type_string($testip);send_key 'tab';
    assert_and_click('suma-system-formula-dhcpd-form-save');

    # apply high state
    assert_and_click('suma-system-formulas');
    assert_and_click('suma-system-formula-highstate');
    wait_screen_change {
      assert_and_click('suma-system-formula-event');
    };
    # wait for high state
    # check for success
    send_key_until_needlematch('suma-system-highstate-finish', 'ctrl-r', 10, 15);
    wait_screen_change {
      assert_and_click('suma-system-highstate-finish');
    };
    send_key_until_needlematch('suma-system-highstate-success', 'pgdn');

    # signal minion to check configuration
    barrier_wait('tftp_formula');
    barrier_wait('tftp_formula_finish');
  }
}

1;
