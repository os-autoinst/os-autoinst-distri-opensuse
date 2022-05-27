# SUSE's SLES4SAP openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install HANA with SAP Installation Wizard. Verify installation with
# sles4sap/hana_test
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use utils qw(file_content_replace type_string_slow);
use x11utils qw(turn_off_gnome_screensaver);
use version_utils qw(package_version_cmp is_sle);

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('HANA'));
    my $timeout = bmwqemu::scale_timeout(3600);
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');

    $self->select_serial_terminal;

    # Check that there is enough RAM for HANA
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    # Keep only the generic HANA partitioning profile and link it to the needed model
    # NOTE: fix name is used here (Dell), but something more flexible should be done later!
    enter_cmd "rm -f /usr/share/YaST2/data/y2sap//hana_partitioning_Dell*.xml";
    enter_cmd "ln -s hana_partitioning.xml '/usr/share/YaST2/data/y2sap/hana_partitioning_Dell Inc._generic.xml'";

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    # Install libopenssl1_0_0 for older (<SPS03) HANA versions on SLE15+
    $self->install_libopenssl_legacy($path);

    # Get package version
    my $wizard_package_version = script_output("rpm -q --qf '%{VERSION}\n' sap-installation-wizard");

    if (check_var('DESKTOP', 'textmode')) {
        script_run "yast2 sap-installation-wizard; echo yast2-sap-installation-wizard-status-\$? > /dev/$serialdev", 0;
        assert_screen 'sap-installation-wizard';
    } else {
        select_console 'x11';
        mouse_hide;    # Hide the mouse so no needle will fail because of the mouse pointer appearing
        x11_start_program('xterm');
        turn_off_gnome_screensaver;    # Disable screensaver
        enter_cmd "killall xterm";
        assert_screen 'generic-desktop';
        x11_start_program('yast2 sap-installation-wizard', target_match => 'sap-installation-wizard');
    }

    # The following commands are identical in text or graphical mode
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'ret' if check_var('DESKTOP', 'textmode');
    send_key 'alt-p';
    send_key_until_needlematch 'sap-wizard-inst-master-empty', 'backspace', 30 if check_var('DESKTOP', 'textmode');
    type_string_slow "$path", wait_still_screen => 1;
    save_screenshot;
    send_key $cmd{next};
    assert_screen 'sap-wizard-supplement-medium', $timeout;    # We need to wait for the files to be copied
    send_key $cmd{next};
    if (package_version_cmp($wizard_package_version, '4.3.0') <= 0) {
        assert_screen 'sap-wizard-additional-repos';
        send_key $cmd{next};
    }
    assert_screen 'sap-wizard-hana-system-parameters';
    send_key 'alt-s';    # SAP SID
    send_key_until_needlematch 'sap-wizard-sid-empty', 'backspace' if check_var('DESKTOP', 'textmode');
    type_string $sid;
    wait_screen_change { send_key 'alt-a' };    # SAP Password
    type_password $sles4sap::instance_password;
    wait_screen_change { send_key 'tab' };
    type_password $sles4sap::instance_password;
    if (is_sle('<15-SP4')) {
        wait_screen_change { send_key $cmd{ok} };
    } else {
        wait_screen_change { send_key $cmd{next} };
    }
    assert_screen 'sap-wizard-profile-ready', 300;
    send_key $cmd{next};

    while (1) {
        assert_screen [qw(sap-wizard-disk-selection-warning sap-wizard-disk-selection sap-wizard-partition-issues sap-wizard-continue-installation sap-product-installation)], no_wait => 1;
        last if match_has_tag 'sap-product-installation';
        send_key $cmd{next} if match_has_tag 'sap-wizard-disk-selection-warning';    # A warning can be shown
        if (match_has_tag 'sap-wizard-disk-selection') {
            assert_and_click 'sap-wizard-disk-selection';    # Install in sda
            send_key 'alt-o';
        }
        send_key 'alt-o' if match_has_tag 'sap-wizard-partition-issues';
        send_key 'alt-y' if match_has_tag 'sap-wizard-continue-installation';
        wait_still_screen 1;    # Slow down the loop
    }

    if (check_var('DESKTOP', 'textmode')) {
        wait_serial('yast2-sap-installation-wizard-status-0', $timeout) || die "'yast2 sap-installation-wizard' didn't finish";
    } else {
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

    # Enable autostart of HANA HDB, otherwise DB will be down after the next reboot
    # NOTE: not on HanaSR, as DB is managed by the cluster stack
    unless (get_var('HA_CLUSTER')) {
        select_console 'root-console' unless check_var('DESKTOP', 'textmode');
        my $hostname = script_output 'hostname';
        file_content_replace("/hana/shared/${sid}/profile/${sid}_HDB${instid}_${hostname}", '^Autostart[[:blank:]]*=.*' => 'Autostart = 1');
    }

    # Upload installations logs
    $self->upload_hana_install_log;
}

sub test_flags {
    return {fatal => 1};
}

1;
