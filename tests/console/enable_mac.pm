# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: containers
# Summary: Enable SELinux or AppArmor
#
# Maintainer: QA-C team <qa-c@suse.de>

use base "consoletest";
use testapi;
use serial_terminal qw(select_serial_terminal);
use Utils::Systemd qw(systemctl);
use Utils::Logging 'save_and_upload_log';
use bootloader_setup qw(replace_grub_cmdline_settings);
use power_action_utils qw(power_action);
use utils qw(zypper_call);

# Taken from tests/transactional/enable_selinux.pm
sub check_enforcing {
    assert_script_run('selinuxenabled');
    validate_script_output("getenforce", sub { m/Enforcing/ });
    validate_script_output("sestatus", sub { m/Current mode:.*enforcing/ });
    validate_script_output("sestatus", sub { m/Mode from config file:.*enforcing/ });
    record_info('SELinux', script_output('sestatus'));
    record_info('Audit report', script_output('aureport'));
    record_info('Audit denials', script_output('aureport -a', proceed_on_failure => 1));
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $current_mac = script_output("grep -Eo '(selinux|apparmor)' /sys/kernel/security/lsm");
    my $security_mac = get_required_var("SECURITY_MAC");
    die "Invalid value for SECURITY_MAC: $security_mac" unless ($security_mac =~ /selinux|apparmor/);

    if ($security_mac eq $current_mac) {
        record_info "SECURITY_MAC", "SECURITY_MAC is already $security_mac";
    } else {
        record_info "SECURITY_MAC", "Switching from $current_mac to $security_mac";

        zypper_call "in -t pattern $security_mac";

        if ($security_mac eq "selinux") {
            replace_grub_cmdline_settings('security=apparmor', 'security=selinux selinux=1', update_grub => 1);
            assert_script_run "sed -i -e 's/^SELINUX=.*/SELINUX=enforcing/g' /etc/selinux/config";
        } else {
            replace_grub_cmdline_settings('security=selinux selinux=1', 'security=apparmor', update_grub => 1);
            assert_script_run "rm -f /etc/selinux/config";
        }

        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 300);
        select_serial_terminal;

        zypper_call "rm --clean-deps -t pattern $current_mac" if ($current_mac);
    }

    $current_mac = script_output("grep -Eo '(selinux|apparmor)' /sys/kernel/security/lsm");
    die "$current_mac != $security_mac" if ($current_mac ne $security_mac);

    if ($security_mac eq "selinux") {
        systemctl 'is-enabled auditd';
        check_enforcing;
    } else {
        validate_script_output("aa-status", sub { m/profiles are in enforce mode/ });
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
