# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start the installation process on s390x zVM using the z3270
#   terminal and an ssh connection
# Maintainer: Wei Gao <wegao@suse.de>


package install_11sp4_configuration;

use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

use bootloader_setup;
use registration;


sub run {
    my $self = shift;

    # reconnect console after reboot
    my $login_ready = qr/starting VNC server/;
    my $timeout     = 300;
    console('installation')->disable_vnc_stalls;
    console('x3270')->expect_3270(output_delim => $login_ready, timeout => $timeout);
    reset_consoles;
    select_console("installation");

    # for set root user page
    assert_screen "inst-rootpassword";
    for (1 .. 2) {
        wait_screen_change { type_string "$password\t" };
    }
    assert_screen "rootpassword-typed";
    wait_screen_change { send_key $cmd{next} };
    assert_screen 'inst-userpasswdtoosimple';
    wait_screen_change { send_key 'ret' };
    # domain configuration
    assert_screen 'domain-configuration-11sp4-s390';
    wait_screen_change { send_key $cmd{next} };
    # network configuration
    wait_still_screen(5);
    assert_screen 'network-configuration-11sp4-s390';
    wait_screen_change { send_key $cmd{next} };
    # test internet configuration
    wait_still_screen(5);
    assert_screen 'test-internet-11sp4-s390';
    send_key 'alt-o';
    wait_screen_change { send_key $cmd{next} };
    # network service configuration(ca)
    wait_still_screen(5);
    assert_screen 'network-configuration-ca-11sp4-s390';
    send_key 'alt-s';
    wait_screen_change { send_key $cmd{next} };
    # user authentication method
    wait_still_screen(5);
    assert_screen 'user-authentication-11sp4-s390';
    send_key 'alt-o';
    wait_screen_change { send_key $cmd{next} };
    # add new local user
    wait_still_screen(5);
    assert_screen 'inst-usersetup';
    send_key 'alt-f';    # Select full name text field
    wait_screen_change { type_string "$realname" };
    send_key 'tab';      # Select password field
    send_key 'tab';
    for (1 .. 2) {
        wait_screen_change { type_string "$password\t" };
    }
    wait_screen_change { send_key $cmd{next} };
    assert_screen 'inst-userpasswdtoosimple';
    wait_screen_change { send_key 'ret' };
    # release notes
    wait_still_screen(5);
    assert_screen 'release-notes-11sp4-s390';
    wait_screen_change { send_key $cmd{next} };
    # hardware configuration
    wait_still_screen(5);
    assert_screen 'hardware-configuration-11sp4-s390';
    send_key 'alt-s';
    wait_screen_change { send_key $cmd{next} };
    # installation complete
    wait_still_screen(5);
    assert_screen 'installation-complete-11sp4-s390';
    wait_screen_change { send_key 'alt-f' };

    #sleep 100; #wait reboot

    select_console('iucvconn', await_console => 0);
    select_console('root-console');
    assert_script_run "cat /etc/os-release";
    $self->result('ok');

}

1;
