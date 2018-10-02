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

    # Add host's IP to /etc/hosts
    select_console 'root-console';
    assert_script_run 'echo $(ip -4 addr show dev eth0 | sed -rne "/inet/s/[[:blank:]]*inet ([0-9\.]*).*/\1/p") $(hostname) >> /etc/hosts';
    select_console 'x11';

    x11_start_program('xterm -geometry 160x45+5+5', target_match => 'xterm-susetest');
    turn_off_gnome_screensaver;
    type_string "killall xterm\n";

    assert_screen 'generic-desktop';
    x11_start_program 'yast2 sap-installation-wizard';
    assert_screen 'sap-installation-wizard';

    # Choose nfs://
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'alt-p';
    type_string_slow "$path", wait_still_screen => 1;
    # Next
    send_key 'tab';
    send_key 'alt-n';

    assert_screen 'sap-wizard-copying-media';

    # "Do you use a Supplement/3rd-Party SAP software medium?"
    assert_screen 'sap-wizard-supplement-medium', 3000;
    # No
    send_key 'alt-n';
    assert_screen 'sap-wizard-additional-repos';
    # Next
    send_key 'alt-n';

    # Don't change this. The needle has this SID.
    my $sid      = 'NDB';
    my $password = 'Qwerty_123';
    set_var('PASSWORD', $password);

    assert_screen 'sap-wizard-hana-system-parameters';
    # SAP SID
    send_key 'alt-s';
    type_string $sid;
    # SAP Master Password
    send_key 'alt-a';
    type_password $password;
    send_key 'tab';
    type_password $password;
    # Ok
    send_key 'alt-o';

    set_var('SAPADM', lc($sid) . 'adm');

    assert_screen 'sap-wizard-performing-installation', 60;

    # "Are there more SAP products to be prepared for installation?"
    assert_screen 'sap-wizard-profile-ready', 300;
    # No
    send_key 'alt-n';

    # "Do you want to continue the installation?"
    # "Your system does not meet the requirements..."
    assert_screen 'sap-wizard-continue-installation';
    # Yes
    send_key 'alt-y';

    assert_screen 'sap-product-installation';

    assert_screen [qw(sap-wizard-installation-summary sap-wizard-finished sap-wizard-failed sap-wizard-error)], 4000;
    if (match_has_tag 'sap-wizard-installation-summary') {
        send_key 'alt-o';
        assert_screen 'generic-desktop', 600;
    } else {
        if (match_has_tag 'sap-wizard-error') {
            send_key 'alt-o';
        } elsif (match_has_tag 'sap-wizard-failed') {
            send_key 'tab';
            send_key 'ret';
        }
        # Wait for SAP wizard to finish writing logs
        assert_screen 'generic-desktop', 90;
        die "Failed";
    }
}

sub test_flags {
    # 'fatal'          - abort whole test suite if this fails (and set overall state 'failed')
    # 'ignore_failure' - if this module fails, it will not affect the overall result at all
    # 'milestone'      - after this test succeeds, update 'lastgood'
    # 'norollback'     - don't roll back to 'lastgood' snapshot if this fails
    return {fatal => 1};
}

sub post_fail_hook {
    my $self = shift;
    select_console 'root-console';

    assert_script_run 'tar cf /tmp/logs.tar /var/adm/autoinstall/logs; xz -9v /tmp/logs.tar';
    upload_logs '/tmp/logs.tar.xz';
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
}

1;
