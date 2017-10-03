# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of DNS
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use selenium;

sub run {
    my ($self) = @_;
    $self->register_barriers('bind_formula', 'bind_formula_finish');
    if (check_var('SUMA_SALT_MINION', 'branch')) {
        $self->registered_barrier_wait('bind_formula');
        script_output('cat /etc/named.d/named.conf.local');
        script_output('cat /var/lib/named/branch1.txt');
        assert_script_run 'host salt.internal.suma.openqa.suse.de 127.0.0.1 | grep 10.0.2.10';
        assert_script_run 'host branchserver1.internal.suma.openqa.suse.de 127.0.0.1 | grep 192.168.1.1';
        assert_script_run 'host tftp.internal.suma.openqa.suse.de 127.0.0.1 | grep 192.168.1.1';
        $self->registered_barrier_wait('bind_formula_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        $self->registered_barrier_wait('bind_formula');
        $self->registered_barrier_wait('bind_formula_finish');
    }
    else {
        $self->install_formula('bind-formula');

        select_console 'root-console';

        # share one pillar file between tests, each test appends its own config
        script_output 'cat >>/srv/pillar/suma_test.sls << EOT
bind:
  configured_zones:
    internal.suma.openqa.suse.de:                          # First domain zone
      type: master                                # We re the master of this zone
      notify: False

    1.168.192.in-addr.arpa:                       # Reverse lookup for local IPs
      type: master                                # As above
      notify: False


### Define zone records in pillar ###
  available_zones:
    internal.suma.openqa.suse.de:
      file: branch1.txt
      soa:                                        # Declare the SOA RRs for the zone
        ns: branchserver1.internal.suma.openqa.suse.de                       # Required
        contact: hostmaster.internal.suma.openqa.suse.de # Required
        serial: 2017041001                        # Required
        class: IN                                 # Optional. Default: IN
        refresh: 8600                             # Optional. Default: 12h
        retry: 900                                # Optional. Default: 15m
        expiry: 86000                             # Optional. Default: 2w
        nxdomain: 500                             # Optional. Default: 1m
        ttl: 8600                                 # Optional. Not set by default
      records:                                    # Records for the zone, grouped by type
        A:
          branchserver1: 192.168.1.1
          \'\$GENERATE 0-50  dhcp\$\': 192.168.1.$
          salt: 10.0.2.10

        NS:
          \'@\':
            - branchserver1
        CNAME:
          ftp: branchserver1.internal.suma.openqa.suse.de.
          tftp: branchserver1.internal.suma.openqa.suse.de.
          dns: branchserver1.internal.suma.openqa.suse.de.
          dhcp: branchserver1.internal.suma.openqa.suse.de.
EOT
';
        assert_script_run 'echo "base:
  \'*\':
    - suma_test" > /srv/pillar/top.sls';

        script_output "salt '*' state.apply bind";
        script_output "salt '*' state.apply bind/config";

        select_console 'x11', tags => 'suma_welcome_screen';

        #    assert_and_click('suma-salt-menu');
        #    assert_and_click('suma-salt-formulas');
        #    assert_and_click('suma-branch-network-formula-details');
        #    assert_screen('suma-branch-network-formula-details-screen');

        # no form yet
        #     assert_and_click('suma-systems-menu');
        #     assert_and_click('suma-systems-submenu');
        #     assert_and_click('suma-system-all');
        #     assert_and_click('suma-system-branch');
        #     assert_and_click('suma-system-formulas');
        #     send_key_until_needlematch('suma-system-formula-bind', 'down', 40, 1);
        #     assert_and_click('suma-system-formula-bind');
        #     assert_and_click('suma-system-formulas-save');
        #     assert_and_click('suma-system-formula-bind-tab');
        #     assert_and_click('suma-system-formula-bind-form');

        #    assert_and_click('suma-system-formula-form-save');

        # apply high state
        #    assert_and_click('suma-system-formulas');
        #    assert_and_click('suma-system-formula-highstate');
        #    wait_screen_change {
        #      assert_and_click('suma-system-formula-event');
        #    };
        # wait for high state
        # check for success
        #    send_key_until_needlematch('suma-system-highstate-finish', 'ctrl-r', 10, 15);
        #    wait_screen_change {
        #      assert_and_click('suma-system-highstate-finish');
        #    };
        #    send_key_until_needlematch('suma-system-highstate-success', 'pgdn');
        $self->registered_barrier_wait('bind_formula');
        $self->registered_barrier_wait('bind_formula_finish');

    }
}

sub test_flags() {
    return {milestone => 1};
}

1;
