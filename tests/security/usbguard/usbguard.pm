# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'usbguard' can work:
#          '# systemctl enable usbguard.service',
#          '# systemctl start usbguard.service',
#          '# systemctl status/is-active usbguard.service',
#          '# usbguard generate-policy', '# usbguard allow-device',
#          '# usbguard list-devices', '# usbguard block-device'
#          '# check/cat '/var/log/usbguard/usbguard-audit.log',
#          '# usbguard add-user', '# usbguard remove-user',
#          '# usbguard get-parameter', '# usbguard set-parameter'
#          '# usbguard generate/list/install/remove rules'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#102566, tc#1769830

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub restart_usbguard_allow_keyboard {
    # When doing restart usbguared service it will block the "USB Keyboard" on aarch64,
    # so workaround it for all arches just in case (allow it permanently)
    assert_script_run('systemctl --no-pager start usbguard.service; id=$(usbguard list-devices | grep block | grep Keyboard | cut -f1 -d :); [[ $id ]] && usbguard allow-device -p $id || echo \"No blocked keyboard found\"');
}

sub run {
    my $out = '';
    my $user = 'usbguard';
    my $allow = 'allow';
    my $block = 'block';
    my $msg = 'Tablet';
    my $f_rules_default = '/etc/usbguard/rules.conf';
    my $f_rules_test = '/etc/usbguard/rules_test.conf';
    my $f_IPCAccessControl = '/etc/usbguard/IPCAccessControl.d/\:' . "$user";
    my $f_usbguard_audit_log = '/var/log/usbguard/usbguard-audit.log';

    select_console 'root-console';

    # 0. Set up environment
    # Install usbguard packages
    zypper_call('in libusbguard1 usbguard usbguard-devel usbguard-tools', timeout => 900);

    # Start audit service
    systemctl('restart auditd.service');

    # Create /etc/nsswitch.conf for Tumbleweed otherwise there will be an Error like
    # "usbguard-daemon: NSSwitch parsing: /etc/nsswitch.conf: No such file or directory"
    # when start usbguard service
    # On newer environments, nsswitch.conf is located in /usr/etc/
    script_run("f=/etc/nsswitch.conf; [ ! -f \$f ] && cp /usr\$f \$f");

    # 1. Verify usbguard service can be started
    # Enable usbguard service
    assert_script_run('usb-devices');
    assert_script_run('systemctl --no-pager enable usbguard.service');
    # Restart usbguared service and allow the "USB Keyboard" just in case
    restart_usbguard_allow_keyboard();
    assert_script_run('systemctl --no-pager status usbguard.service');

    # Check usbguard service is 'active'
    validate_script_output('systemctl is-active usbguard.service', sub { m/active/ });

    # 2. Verify usbguard list-devices by default
    # Verify usbguard list-devices and check the default status
    validate_script_output('usbguard list-devices', sub { m/$msg/ });

    # 3. Verify usbguard deauthorize a usb device and check the status
    # Pick up a usb device
    my $device_id = script_output("usbguard list-devices | grep $msg | cut -f1 -d ':' | head -1");
    # Cleanup usbguard log file
    script_output("echo > $f_usbguard_audit_log");
    # Deauthorize this device
    assert_script_run("usbguard block-device $device_id");
    # Check this device should be in "block"
    validate_script_output('usbguard list-devices', sub { m/$device_id: $block/ });
    # Double check the record is recorded
    validate_script_output("cat $f_usbguard_audit_log", sub { m/target.new=.*$block.*target.old=.*'/sx });

    # 4. Verify usbguard allow the usb device and check the status
    # Cleanup usbguard log file
    assert_script_run("echo > $f_usbguard_audit_log");
    # Allow this device
    assert_script_run("usbguard allow-device $device_id");
    # Check this device should be in "allow"
    validate_script_output('usbguard list-devices', sub { m/$device_id: $allow/ });
    # Double check the record is recorded
    validate_script_output("cat $f_usbguard_audit_log", sub { m/target.new=.*$allow.*target.old=.*$block.*'/sx });

    # 5. Verify usbguard add/remove a usbguard user
    # Add a usbguard user
    assert_script_run("usbguard add-user -g $user --devices=modify,list,listen --policy=list --exceptions=listen");
    # Double check: related file contain this user
    validate_script_output("cat $f_IPCAccessControl", sub { m/Devices=list,modify,listen.*Policy=list.*Exceptions=listen/sx });
    # Remove this user
    assert_script_run("usbguard remove-user -g $user");
    # Double check: related file was removed
    if (script_run("! [[ -e $f_IPCAccessControl ]]")) {
        die("Error: $f_IPCAccessControl should be removed");
    }

    # 6. Verify usbguard generate/install/list/remove policy/rules
    # List rules (by default)
    $out = script_run('usbguard list-rules');
    die("Error: there should no rules by default") if $out =~ m/$msg/;
    # Remove this rule and check the rule does not exist
    assert_script_run("cp $f_rules_default $f_rules_default.bk");
    assert_script_run("echo > $f_rules_default");
    # Restart usbguared service and allow the "USB Keyboard" just in case
    restart_usbguard_allow_keyboard();
    $out = script_run('usbguard list-rules');
    die("Error: there should no these rules if rules config file is empty") if $out =~ m/$msg/;

    # Clean up
    assert_script_run("mv $f_rules_default.bk $f_rules_default");
    systemctl('restart usbguard.service');

    # Generate usbguard policy/rules
    assert_script_run("usbguard generate-policy > $f_rules_test");
    validate_script_output("cat $f_rules_test", sub { m/$msg/ });
    # Install this rule and check the rule exists
    assert_script_run("install -m 0600 -o root -g root $f_rules_test $f_rules_default");
    systemctl('restart usbguard.service');
    validate_script_output('usbguard list-rules', sub { m/$msg/ });

    # Run usbguard remove-rule
    assert_script_run("usbguard remove-rule 1");
    # usbguard list-rules there should no rules
    $out = script_run('usbguard list-rules');
    die("Error: there should no these rules") if $out =~ m/$msg/;

    # 7. Verify usbguard get/set parameter
    # Get parameter InsertedDevicePolicy
    validate_script_output('usbguard get-parameter InsertedDevicePolicy', sub { m/apply-policy/ });
    # Get parameter ImplicitPolicyTarget
    validate_script_output('usbguard get-parameter ImplicitPolicyTarget', sub { m/$block/ });
    # Set parameter ImplicitPolicyTarget and verify
    assert_script_run("usbguard set-parameter ImplicitPolicyTarget $allow", sub { m/$block/ });
    validate_script_output('usbguard get-parameter ImplicitPolicyTarget', sub { m/$allow/ });
}

1;
