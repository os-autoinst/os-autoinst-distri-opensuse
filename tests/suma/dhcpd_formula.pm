# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager dhcpd salt formula
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;

sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    # barriers for salt terminal
    barrier_create('dhcp_ready', 2);
    barrier_create('dhcp_ready_finish', 2);

    # configure second interface for dhcp
    assert_script_run "echo \"STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR='192.168.1.1'\nNETMASK='255.255.0.0'\" > /etc/sysconfig/network/ifcfg-eth1";
    assert_script_run 'ifup eth1';
    assert_script_run 'ip addr';
    assert_script_run 'sed -i -e "s|FW_DEV_INT=.*|FW_DEV_INT=eth1|" -e "s|FW_ROUTE=.*|FW_ROUTE=yes|" -e "s|FW_MASQUERADE=.*|FW_MASQUERADE=yes|" /etc/sysconfig/SuSEfirewall2';
    assert_script_run 'systemctl restart SuSEfirewall2';
    barrier_wait('dhcpd_formula');

    # minion test
    assert_script_run('systemctl is-active dhcpd.service');
    # TODO check files are proper
    # allow salt terminal to continue
    barrier_wait('dhcp_ready');
    # and wait for it to finish
    barrier_wait('dhcp_ready_finish');
    # allow salt master to continue
    barrier_wait('dhcpd_formula_finish');
  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('dhcpd_formula');
    barrier_wait('dhcp_ready');
    assert_script_run('/usr/lib/wicked/bin/wickedd-dhcp4 --test eth0');
    # TODO test concrete data
    barrier_wait('dhcp_ready_finish');
    barrier_wait('dhcpd_formula_finish');
  }
  else {
    $self->install_formula('dhcpd-formula');
    assert_and_click('suma-salt-menu');
    assert_and_click('suma-salt-formulas');
    assert_and_click('suma-dhcpd-formula-details');
    assert_screen('suma-dhcpd-formula-details-screen');
    assert_and_click('suma-systems-menu');
    assert_and_click('suma-systems-submenu');
    assert_and_click('suma-system-all');
    assert_and_click('suma-system-branch');
    assert_and_click('suma-system-formulas');
    send_key_until_needlematch('suma-system-formula-dhcpd', 'down', 40, 1);
    assert_and_click('suma-system-formula-dhcpd');
    assert_and_click('suma-system-formulas-save');
    assert_and_click('suma-system-formula-dhcpd-tab');
    # fill in form details
    assert_and_click('suma-system-formula-dhcpd-form');
    
    # domain
    type_string('internal.suma.openqa.suse.de');send_key 'tab';
    # dns servers
    type_string('10.100.2.10');send_key 'tab'; # dns1.suse.cz for now, FIXME: dns on branch server
    # device
    type_string('eth1');send_key 'tab';
    # skip leases
    send_key 'tab';send_key 'tab';
    # network
    type_string('192.168.0.0');send_key 'tab';
    # netmask
    type_string('255.255.0.0');send_key 'tab';
    # dhcp range
    type_string('192.168.242.51,192.168.243.151');send_key 'tab';
    # broadcast
    type_string('192.168.255.255');send_key 'tab';
    # routers
    type_string('192.168.1.1');send_key 'tab';
    # next server
    type_string('192.168.1.1');send_key 'tab';
    # pxe filename
    type_string('/boot/pxelinux.0');send_key 'tab';
    #assert_screen('suma-system-formula-dhcpd-form-filled');
    assert_and_click('suma-system-formula-dhcpd-form-save');

    # apply high state
    assert_and_click('suma-system-formulas');
    assert_and_click('suma-system-formula-highstate');
    wait_screen_change {
      assert_and_click('suma-system-formula-event');
    };
    # wait for high state
    # check for success
    send_key_until_needlematch('suma-system-highstate-finish', 'ctrl-r');
    wait_screen_change {
      assert_and_click('suma-system-highstate-finish');
    };
    send_key_until_needlematch('suma-system-highstate-success', 'pgdn');

    # signal minion to check configuration
    barrier_wait('dhcpd_formula');
    barrier_wait('dhcpd_formula_finish');
  }
}

1;
