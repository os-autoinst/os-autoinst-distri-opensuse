# SUSE's SLES4SAP openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install HANA and Business One with SAP Installation Wizard.
# Verify installation with sles4sap/hana_test
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(file_content_replace type_string_slow);
use x11utils qw(turn_off_gnome_screensaver);
use version_utils qw(package_version_cmp is_sle);

sub turn_off_low_disk_warning {
    enter_cmd q@VAL=$(gsettings get org.gnome.settings-daemon.plugins.housekeeping ignore-paths | sed -e "s,.$,\, '/hana/shared'\, '/hana/data'\, '/hana/log'],")@;
    enter_cmd 'echo $VAL';
    enter_cmd 'gsettings get org.gnome.settings-daemon.plugins.housekeeping ignore-paths';
    enter_cmd 'gsettings set org.gnome.settings-daemon.plugins.housekeeping ignore-paths "$VAL"';
    enter_cmd 'gsettings get org.gnome.settings-daemon.plugins.housekeeping ignore-paths';
    save_screenshot;
}

sub b1_wiz_workaround {
    my ($install_bin, $b1_cfg, $tout) = @_;
    assert_script_run "curl -f -v -O " . autoinst_url . "/data/sles4sap/b1_workaround.tar.gz";
    assert_script_run "tar xvf b1_workaround.tar.gz -C /tmp";
    assert_script_run "chmod +x /tmp/*.sh";
    my $code_to_inject = <<'EOT';
        pid_installer=$!
        sleep 10
        kill -SIGSTOP $pid_installer
        cd /tmp/B1ServerTools*
        cp -f /tmp/*.sh opt/sap/SAPBusinessOne/Common/support/bin
        kill -SIGCONT $pid_installer
EOT
    # format $code_to_inject so shell script runs correctly
    chomp $code_to_inject;
    $code_to_inject =~ s/\n/\\\n/g;
    assert_script_run("sed -i '/pid_installer=\$!/c\\ $code_to_inject' \"/usr/lib/YaST2/bin/b1_inst.sh\"");
}

sub run {
    my ($self) = @_;
    my $bone;
    my ($proto, $path) = $self->fix_path(get_required_var('HANA'));
    if (get_var('BONE')) {
        ($proto, $bone) = $self->fix_path(get_required_var('BONE'));
    }
    my $timeout = bmwqemu::scale_timeout(3600);
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');

    select_serial_terminal;

    # Check that there is enough RAM for HANA
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    # Keep only the generic HANA partitioning profile and link it to the needed model
    # NOTE: fix name is used here (Dell), but something more flexible should be done later!
    my $previous_dir = is_sle('15+') ? '/usr/share/YaST2/data/y2sap/' : '/usr/share/YaST2/include/sap-installation-wizard';
    assert_script_run "rm -f $previous_dir/hana_partitioning_Dell*.xml";
    assert_script_run "ln -s hana_partitioning.xml '$previous_dir/hana_partitioning_Dell Inc._generic.xml'";

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    # Install libopenssl1_0_0 for older (<SPS03) HANA versions on SLE15+
    $self->install_libopenssl_legacy($path);

    # Get package version
    # in SLE15SP5 and above wizard is called "bone-installation-wizard"
    my $wiz_name = (is_sle('15-SP5+') and get_var('BONE')) ? "bone-installation-wizard" : "sap-installation-wizard";
    my $wizard_package_version = script_output("rpm -q --qf '%{VERSION}\n' $wiz_name");

    # initial workaround for 15-SP7 and b1 installer 2505
    $self->b1_workaround_os_version;

    # workaround for broken b1 installer and curl 8.14
    my $package_version = script_output "rpm -q --qf 'curlver=%{VERSION}\n' curl";
    $package_version =~ /curlver=([\d\.]+)/;
    $package_version = $1;
    die 'Could not determine curl version' unless ($package_version);
    if (is_sle('>=15-SP4') && package_version_cmp($package_version, '8.14.1') <= 0) {
        record_soft_failure "jsc#TEAM-10632 - Workaround for Business One due to bsc#1246964 / libcurl update";
        b1_wiz_workaround;
    }

    # start wizard
    if (check_var('DESKTOP', 'textmode')) {
        script_run "yast2 sap-installation-wizard; echo yast2-sap-installation-wizard-status-\$? > /dev/$serialdev", 0;
        assert_screen 'sap-installation-wizard';
    } else {
        select_console 'x11';
        mouse_hide;    # Hide the mouse so no needle will fail because of the mouse pointer appearing
        x11_start_program('xterm');
        turn_off_gnome_screensaver;    # Disable screensaver
        turn_off_low_disk_warning;
        enter_cmd "killall xterm";
        assert_screen 'generic-desktop';
        x11_start_program('yast2 sap-installation-wizard', target_match => 'sap-installation-wizard');
    }

    # The following commands are identical in text or graphical mode
    send_key 'tab';
    send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
    send_key 'ret' if check_var('DESKTOP', 'textmode');
    send_key 'alt-p';
    send_key_until_needlematch 'sap-wizard-inst-master-empty', 'backspace', 31 if check_var('DESKTOP', 'textmode');
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
    if (is_sle('>=15-SP5')) {
        wait_screen_change { send_key 'alt-p' };    # SAP Password
    } else {
        wait_screen_change { send_key 'alt-a' };    # SAP Password
    }
    type_password $sles4sap::instance_password;
    wait_screen_change { send_key 'tab' };
    type_password $sles4sap::instance_password;
    if (is_sle('<15-SP4')) {
        wait_screen_change { send_key $cmd{ok} };
    } else {
        wait_screen_change { send_key $cmd{next} };
    }
    assert_screen 'sap-wizard-profile-ready', 300;

    # BONE requires another repo
    if (get_var('BONE')) {
        send_key 'alt-y';
        wait_screen_change { send_key 'tab' };
        send_key_until_needlematch 'sap-wizard-proto-' . $proto . '-selected', 'down';
        send_key 'ret' if check_var('DESKTOP', 'textmode');
        send_key 'alt-p';
        send_key_until_needlematch 'sap-wizard-inst-master-empty', 'backspace', 31 if check_var('DESKTOP', 'textmode');
        type_string_slow "$bone", wait_still_screen => 1;
        save_screenshot;
        send_key $cmd{next};
        assert_screen 'sap-wizard-supplement-medium', $timeout;    # We need to wait for the files to be copied
        send_key $cmd{next};
        assert_screen 'sap-wizard-profile-ready', 300;
        send_key 'alt-n';
        # BONE wizard prints a warning about compatibility, usual safe to ignore
        assert_screen 'sap-wizard-not-certified', $timeout;
        send_key 'alt-y';
    } else {
        send_key $cmd{next};
    }

    # wait for wizard to finish
    while (1) {
        wait_still_screen 1;    # Slow down the loop
        assert_screen [qw(sap-wizard-disk-selection-warning sap-wizard-disk-selection sap-wizard-partition-issues sap-wizard-continue-installation sap-product-installation)], no_wait => 1;
        last if match_has_tag 'sap-product-installation';
        send_key $cmd{next} if match_has_tag 'sap-wizard-disk-selection-warning';    # A warning can be shown
        if (match_has_tag 'sap-wizard-disk-selection') {
            assert_and_click 'sap-wizard-disk-selection';    # Install in sda
            send_key 'alt-o';
        }
        send_key 'alt-o' if match_has_tag 'sap-wizard-partition-issues';
        send_key 'alt-y' if match_has_tag 'sap-wizard-continue-installation';
    }

    if (check_var('DESKTOP', 'textmode')) {
        wait_serial('yast2-sap-installation-wizard-status-0', $timeout) || die "'yast2 sap-installation-wizard' didn't finish";
    } else {
        assert_screen [qw(sap-wizard-installation-summary sap-wizard-finished sap-wizard-failed sap-wizard-error sap-wizard-missing-32bit-client)], $timeout;
        send_key $cmd{ok};
        if (match_has_tag 'sap-wizard-installation-summary') {
            assert_screen 'generic-desktop', 1200;
        } elsif (match_has_tag 'sap-wizard-missing-32bit-client') {
            record_soft_failure "bsc#1227390 - Missing 32-bit client happened";
            assert_screen 'generic-desktop', 1200;
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
