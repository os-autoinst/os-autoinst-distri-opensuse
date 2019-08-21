# SUSE's SLES4SAP openQA tests
#
# Copyright (C) 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install HANA with SAP Installation Wizard. Verify installation with
# sles4sap/hana_test
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'turn_off_gnome_screensaver';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my ($proto, $path) = split m|://|, get_required_var('MEDIA');
    die "Currently supported protocols are nfs and smb" unless $proto =~ /^(nfs|smb)$/;

    my $timeout  = 3600 * get_var('TIMEOUT_SCALE', 1);
    my $sid      = get_required_var('INSTANCE_SID');
    my $password = 'Qwerty_123';
    set_var('PASSWORD', $password);

    select_console 'root-console';

    # Check that there is enough RAM for HANA
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    # Keep only the generic HANA partitioning profile and link it to the needed model
    # NOTE: fix name is used here (Dell), but something more flexible should be done later!
    type_string "rm -f /usr/share/YaST2/include/sap-installation-wizard/hana_partitioning_Dell*.xml\n";
    type_string "ln -s hana_partitioning.xml '/usr/share/YaST2/include/sap-installation-wizard/hana_partitioning_Dell Inc._generic.xml'\n";

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    select_console 'x11';
    # Hide the mouse so no needle will fail because of the mouse pointer appearing
    mouse_hide;

    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    type_string "killall xterm\n";
    assert_screen 'generic-desktop';
    x11_start_program('yast2 sap-installation-wizard', target_match => 'sap-installation-wizard');
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'alt-p';
    type_string_slow "$path", wait_still_screen => 1;
    save_screenshot;
    send_key 'tab';
    send_key $cmd{next};
    assert_screen 'sap-wizard-copying-media',     120;
    assert_screen 'sap-wizard-supplement-medium', $timeout;
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
    assert_screen 'sap-wizard-performing-installation', 120;
    assert_screen 'sap-wizard-profile-ready',           300;
    send_key $cmd{next};
    while (1) {
        assert_screen [qw(sap-wizard-disk-selection-warning sap-wizard-disk-selection sap-wizard-partition-issues sap-wizard-continue-installation sap-product-installation)], no_wait => 1;

        last if match_has_tag 'sap-product-installation';
        send_key $cmd{next} if match_has_tag 'sap-wizard-disk-selection-warning';    # A warning can be shown
        if (match_has_tag 'sap-wizard-disk-selection') {
            # Install in sda
            assert_and_click 'sap-wizard-disk-selection';
            send_key 'alt-o';
        }
        send_key 'alt-o' if match_has_tag 'sap-wizard-partition-issues';
        send_key 'alt-y' if match_has_tag 'sap-wizard-continue-installation';

        # Slow down the loop
        wait_still_screen 1;
    }
    assert_screen [qw(sap-wizard-installation-summary sap-wizard-finished sap-wizard-failed sap-wizard-error)], $timeout;
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
    assert_script_run 'tar cf /tmp/logs.tar /var/adm/autoinstall/logs /var/tmp/hdb*; xz -9v /tmp/logs.tar';
    upload_logs '/tmp/logs.tar.xz';
    assert_script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";
    $self->SUPER::post_fail_hook;
}

1;
