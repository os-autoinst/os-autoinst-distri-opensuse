# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test boot of a terminal
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use utils 'zypper_call';


sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    barrier_wait('saltboot_orchestrate');
    barrier_wait('saltboot_orchestrate_finish');
    script_output 'ls -l /srv/tftpboot/boot/pxelinux.cfg/';

    assert_script_run 'ls /srv/tftpboot/boot/pxelinux.cfg |grep ^01- ';
  }
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    select_console 'root-console';
    barrier_wait('saltboot_orchestrate');
    type_string "shutdown -r now\n";
    assert_screen("suma-image-pxe", 300);
    assert_screen("suma-image-login", 300);

    barrier_wait('saltboot_orchestrate_finish');

    # clear kiwidebug console
    send_key 'alt-f2';
    type_string "exit\n\n\n";
    send_key 'alt-f1';

    reset_consoles;

    select_console 'root-console';
  }
  else {
    select_console 'root-console';
    if (get_var('SALT_DEBUG')) {
        assert_script_run 'systemctl stop salt-master';
        # send salt-master debug log to serial
        type_string "salt-master -l all >/dev/ttyS0 2>&1 &\n";

        sleep 10;
    }
    # maybe something like https://github.com/saltstack/salt/issues/32144 - FIXME: needs to be investigated
    assert_script_run 'salt "*" saltutil.refresh_pillar';
    assert_script_run 'salt -l debug -I "dhcpd:domain_name:internal.suma.openqa.suse.de" test.ping';
    select_console 'x11', tags => 'suma_welcome_screen';

    barrier_wait('saltboot_orchestrate');
    send_key_until_needlematch('suma_pending_minions', 'ctrl-r', 50, 15);
    wait_screen_change {
      assert_and_click('suma_pending_minions');
    };
    send_key_until_needlematch('suma_salt_key_accept', 'right', 40, 1);
    wait_screen_change {
      assert_and_click('suma_salt_key_accept');
    };
    barrier_wait('saltboot_orchestrate_finish');
    assert_and_click('suma_go_home');
    assert_screen('suma_welcome_screen');

    select_console 'root-console';
    if (get_var('SALT_DEBUG')) {
        # stop debug log

        assert_script_run "killall salt-master";
        assert_script_run 'systemctl start salt-master';
    }
    select_console 'x11', tags => 'suma_welcome_screen';
  }
}

1;
