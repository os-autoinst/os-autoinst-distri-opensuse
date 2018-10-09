# SUSE's SLES4SAP openQA tests
#
# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install HANA with SAP Installation Wizard
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base 'sles4sap';
use strict;
use testapi;
use utils 'turn_off_gnome_screensaver';
use utils 'type_string_slow';

sub run {
    my ($self) = @_;
    my ($proto, $path) = split m|://|, get_required_var('MEDIA');
    die "Currently supported protocols are nfs and smb" unless $proto =~ /^(nfs|smb)$/;
    my $QEMURAM = get_required_var('QEMURAM');
    die "QEMURAM=$QEMURAM. The SUT needs at least 32G of RAM" if $QEMURAM < 32768;
    # Don't change this. The needle has this SID.
    my $sid      = 'NDB';
    my $password = 'Qwerty_123';
    set_var('PASSWORD', $password);
    set_var('SAPADM',   lc($sid) . 'adm');

    # Add host's IP to /etc/hosts
    select_console 'root-console';
    assert_script_run 'echo $(ip -4 addr show dev eth0 | sed -rne "/inet/s/[[:blank:]]*inet ([0-9\.]*).*/\1/p") $(hostname) >> /etc/hosts';
    select_console 'x11';

    x11_start_program('xterm', target_match => 'xterm-susetest');
    turn_off_gnome_screensaver;
    type_string "killall xterm\n";
    assert_screen 'generic-desktop';
    x11_start_program('yast2 sap-installation-wizard', target_match => 'sap-installation-wizard');
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'alt-p';
    type_string_slow "$path", wait_still_screen => 1;
    send_key 'tab';
    send_key $cmd{next};
    assert_screen 'sap-wizard-copying-media';
    assert_screen 'sap-wizard-supplement-medium', 3000;
    send_key $cmd{next};
    assert_screen 'sap-wizard-additional-repos';
    send_key $cmd{next};
    assert_screen 'sap-wizard-hana-system-parameters';
    # SAP SID / Password
    send_key 'alt-s';
    type_string $sid;
    wait_screen_change { send_key 'alt-a' };
    type_password $password;
    wait_screen_change { send_key 'tab' };
    type_password $password;
    wait_screen_change { send_key $cmd{ok} };
    assert_screen 'sap-wizard-performing-installation', 60;
    assert_screen 'sap-wizard-profile-ready',           300;
    send_key $cmd{next};
    check_screen 'sap-wizard-continue-installation';
    if (match_has_tag 'sap-wizard-continue-installation') {
        send_key 'alt-y';
    }
    assert_screen 'sap-product-installation';
    assert_screen [qw(sap-wizard-installation-summary sap-wizard-finished sap-wizard-failed sap-wizard-error)], 4000;
    send_key $cmd{ok};
    if (match_has_tag 'sap-wizard-installation-summary') {
        assert_screen 'generic-desktop', 600;
    } else {
        # Wait for SAP wizard to finish writing logs
        check_screen 'generic-desktop', 90;
        die "Failed";
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run 'tar cf /tmp/logs.tar /var/adm/autoinstall/logs; xz -9v /tmp/logs.tar';
    upload_logs '/tmp/logs.tar.xz';
    assert_script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";
    $self->SUPER::post_fail_hook;
}

1;
