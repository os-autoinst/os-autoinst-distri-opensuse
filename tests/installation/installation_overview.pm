# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check installation overview before and after any pattern change
# - Check if install scenario has proposals
# - Check if xen pattern is going to be installed if XEN is defined
# - Unblock sshd
# - Disable firewall if DISABLE_FIREWALL is set
# - Check system target
# Maintainer: Richard Brown <RBrownCCB@opensuse.org>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils qw(is_microos is_sle_micro is_upgrade is_sle is_tumbleweed);
use Utils::Backends qw(is_remote_backend is_hyperv);
use Test::Assert ':all';

sub ensure_ssh_unblocked {
    if (!get_var('UPGRADE') && is_remote_backend) {

        # ssh section is not shown up directly in text mode. Navigate into
        # installation overview frame and hitting down button to get there.
        if (check_var('VIDEOMODE', 'text') and (is_sle_micro() or is_tumbleweed)) {
            if (is_sle_micro) {
                send_key_until_needlematch 'installation-settings-overview-selected', 'tab', 25;
            }
            else {
                send_key_until_needlematch 'installation-settings-release-notes-selected', 'tab', 25;
                send_key 'tab';
            }
            send_key_until_needlematch [qw(ssh-blocked ssh-open)], 'down', 60;
        }
        else {
            send_key_until_needlematch [qw(ssh-blocked ssh-open)], 'tab', 60;
        }
        if (match_has_tag 'ssh-blocked') {
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-c';
                assert_screen 'inst-overview-options';
                send_key 'alt-e';
                send_key 'alt-f';
                assert_screen 'firewall-config';
                send_key 'alt-p';
                send_key 'alt-o';
            }
            else {
                send_key_until_needlematch 'ssh-blocked-selected', 'tab', 26;
                send_key 'ret';
                send_key_until_needlematch 'ssh-open', 'tab';
            }
        }
        #performance ci need disable firewall
        if (get_var('DISABLE_FIREWALL')) {
            send_key_until_needlematch [qw(firewall-enable firewall-disable)], 'tab';
            if (match_has_tag 'firewall-enable') {
                send_key 'alt-c';
                assert_screen 'inst-overview-options';
                send_key 'alt-e';
                send_key 'alt-f';
                assert_screen 'firewall-config';
                send_key 'alt-e';
                assert_screen 'firewall-config-dis';
                send_key 'alt-o';
                assert_screen 'back_to_installation_settings';
            }
        }
    }
}

sub check_default_target {
    my ($self) = @_;
    # Check the systemd target where scenario make it possible
    return if (is_microos || is_sle_micro || is_upgrade || is_hyperv ||
        get_var('REMOTE_CONTROLLER') || (get_var('BACKEND', '') =~ /spvm|pvm_hmc|ipmi/));
    # exclude non-desktop environment and scenarios with edition of package selection (bsc#1167736)
    return if (!get_var('DESKTOP') || get_var('PATTERNS'));
    return if (get_var 'BSC1167736');

    # Set expectations
    my $expected_target = check_var('DESKTOP', 'textmode') ? "multi-user" : "graphical";

    $self->validate_default_target($expected_target);
}

sub set_linux_security_to_none {
    send_key_until_needlematch 'security-section-selected', 'tab', 26;
    send_key 'ret';
    assert_screen 'security-configuration', 120;
    send_key 'alt-s';
    send_key 'pgup';
    assert_screen 'lsm-selected-none';
    send_key 'alt-o';
    assert_screen 'installation-settings-overview-loaded', 120;
}

sub run {
    my ($self) = shift;
    # overview-generation
    # this is almost impossible to check for real
    if (is_microos && check_var('HDDSIZEGB', '10')) {
        # boo#1099762
        assert_screen('installation-settings-overview-loaded-impossible-proposal');
    }
    else {
        # Refer to: https://progress.opensuse.org/issues/47369
        assert_screen "installation-settings-overview-loaded", 420;
        if (get_var('XEN')) {
            if (!check_screen('inst-xen-pattern')) {
                assert_and_click 'installation-settings-overview-loaded-scrollbar-up';
                assert_screen 'inst-xen-pattern';
            }
        }
        # the Installer of 15SP4 requires Apparmor pattern activation by default. If Apparmor not presented in PATTERNS and needle matches
        # select None for Major Linux Security Module.
        set_linux_security_to_none if (is_sle('>=15-SP4') && check_screen("apparmor-not-selected") && !(get_var('PATTERNS') =~ 'default|all|apparmor'));
        ensure_ssh_unblocked;
        until (!check_screen("install-overview-options-evaluating-pkg-selection")) {
            save_screenshot;
        }
        $self->check_default_target();
    }
}

1;
