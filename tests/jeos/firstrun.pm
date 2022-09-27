# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure JeOS
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed is_leap is_opensuse is_microos is_sle_micro);
use Utils::Architectures;
use Utils::Backends;
use jeos qw(expect_mount_by_uuid);
use utils qw(assert_screen_with_soft_timeout ensure_serialdev_permissions);

sub post_fail_hook {
    assert_script_run('timedatectl');
    assert_script_run('locale');
    assert_script_run('cat /etc/vconsole.conf');
    assert_script_run('cat /etc/fstab');
    assert_script_run('ldd --help');
}

sub verify_user_info {
    my (%args) = @_;
    my $user = $args{user_is_root};
    my $lang = is_sle('15+') ? 'en_US' : get_var('JEOSINSTLANG', 'en_US');

    my %tz_data = ('en_US' => 'UTC', 'de_DE' => 'Europe/Berlin');
    assert_script_run("timedatectl | awk '\$1 ~ /Time/ { print \$3 }' | grep ^" . $tz_data{$lang} . "\$");

    my %locale_data = ('en_US' => 'en_US.UTF-8', 'de_DE' => 'de_DE.UTF-8');
    assert_script_run("locale | tr -d \\'\\\" | awk -F= '\$1 ~ /LC_CTYPE/ { print \$2 }' | grep ^" . $locale_data{$lang} . "\$");

    my %keymap_data = ('en_US' => 'us', 'de_DE' => 'de');
    assert_script_run("awk -F= '\$1 ~ /KEYMAP/ { print \$2 }' /etc/vconsole.conf | grep ^" . $keymap_data{$lang} . "\$");

    my %lang_data = ('en_US' => 'For bug reporting', 'de_DE' => 'Eine Anleitung zum Melden');
    # User has locale defined in firstboot, root always defaults to POSIX (i.e. English)
    my $proglang = $args{user_is_root} ? 'en_US' : $lang;
    assert_script_run("ldd --help | grep '^" . $lang_data{$proglang} . "'");
}

sub verify_mounts {
    my $expected_type = {mount_type => (expect_mount_by_uuid) ? 'UUID' : 'LABEL'};

    my @findmnt_entries = grep { /\s$expected_type->{mount_type}.*\stranslated\sto\s/ }
      split(/\n/, script_output('findmnt --verbose --verify'));
    (scalar(@findmnt_entries) > 0) or die "Expected mounts by $expected_type->{mount_type} have not been found\n";

    @findmnt_entries = grep { !/^$expected_type->{mount_type}/ }
      split(/\n/, script_output('findmnt --fstab --raw --noheadings --df'));
    (scalar(@findmnt_entries) == 0) or die "Not all mounts are mounted by $expected_type->{mount_type}\nUnexpected mount(s) ( @findmnt_entries )\n";

    assert_script_run('mount -fva');
}

sub run {
    my ($self) = @_;
    my $lang = is_sle('15+') ? 'en_US' : get_var('JEOSINSTLANG', 'en_US');
    # For 'en_US' pick 'en_US', for 'de_DE' select 'de_DE'
    my %locale_key = ('en_US' => 'e', 'de_DE' => 'd');
    # For 'en_US' pick 'us', for 'de_DE' select 'de'
    my %keylayout_key = ('en_US' => 'u', 'de_DE' => 'd');
    # For 'en_US' pick 'UTC', for 'de_DE' select 'Europe/Berlin'
    my %tz_key = ('en_US' => 'u', 'de_DE' => 'e');

    # JeOS on generalhw
    mouse_hide;
    # https://github.com/openSUSE/jeos-firstboot/pull/82 welcome dialog is shown on all consoles
    # and configuration continues on console where *Start* has been pressed
    unless (is_leap('<15.4') || is_sle('<15-sp4')) {
        assert_screen 'jeos-init-config-screen', 300;
        # Without this 'ret' sometimes won't get to the dialog
        wait_still_screen;
        send_key 'ret';
    }

    # kiwi-templates-JeOS images (sle, opensuse x86_64 only) are build w/o translations
    # jeos-firstboot >= 0.0+git20200827.e920a15 locale warning dialog has been removed
    # TO BE REMOVED *soon*; keep only else part
    if ((is_sle('15+') && is_sle('<15-sp3')) || (is_leap('<15.3') && is_x86_64)) {
        assert_screen 'jeos-lang-notice', 300;
        # Without this 'ret' sometimes won't get to the dialog
        wait_still_screen;
        send_key 'ret';
    } elsif ((is_opensuse && !is_microos && !is_x86_64) || is_sle('=12-sp5')) {
        assert_screen 'jeos-locale', 300;
        send_key_until_needlematch "jeos-system-locale-$lang", $locale_key{$lang}, 51;
        send_key 'ret';
    }

    # Select keyboard layout
    assert_screen 'jeos-keylayout', 300;
    send_key_until_needlematch "jeos-keylayout-$lang", $keylayout_key{$lang}, 31;
    send_key 'ret';

    # Show license
    assert_screen 'jeos-license';
    send_key 'ret';

    # Accept EULA if required
    unless (is_tumbleweed || is_microos) {
        assert_screen 'jeos-doyouaccept';
        send_key 'ret';
    }

    # Select timezone
    send_key_until_needlematch "jeos-timezone-$lang", $tz_key{$lang}, 11;
    send_key 'ret';

    # Enter password & Confirm
    foreach my $password_needle (qw(jeos-root-password jeos-confirm-root-password)) {
        assert_screen $password_needle;
        type_password;
        send_key 'ret';
    }

    if (is_sle || is_sle_micro) {
        assert_screen 'jeos-please-register';
        send_key 'ret';
    }

    if (is_generalhw && is_aarch64 && !is_leap("<15.5")) {
        assert_screen 'jeos-please-configure-wifi';
        send_key 'n';
    }

    # Our current Hyper-V host and it's spindles are quite slow. Especially
    # when there are more jobs running concurrently. We need to wait for
    # various disk optimizations and snapshot enablement to land.
    # Meltdown/Spectre mitigations makes this even worse.
    if (is_generalhw && !defined(get_var('GENERAL_HW_VNC_IP'))) {
        # Wait jeos-firstboot is done and clear screen, as we are already logged-in via ssh
        wait_still_screen;
        $self->clear_and_verify_console;
    }
    else {
        assert_screen [qw(linux-login reached-power-off)], 1000;
        if (match_has_tag 'reached-power-off') {
            die "At least it reaches power off, but booting up failed, see boo#1143051. A workaround is not possible";
        }
    }

    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);

    type_string('1234%^&*()qwerty');
    assert_screen("keymap-letter-data-$lang");
    send_key('ctrl-u');
    # Set 'us' keyboard as openQA can't operate with non-us keyboard layouts
    if ($lang ne 'en_US') {
        # With the foreign keyboard, type 'loadkeys us'
        my %loadkeys_reset = ('de_DE' => 'loadkezs us');
        enter_cmd("$loadkeys_reset{$lang}");
        wait_still_screen;
    }
    # Manually configure root-console as we skipped some parts in root-console's activation
    $testapi::distri->set_standard_prompt('root');
    assert_script_run('setterm -blank 0');

    verify_user_info(user_is_root => 1);

    # Create user account, if image doesn't already contain user
    # (which is the case for SLE images that were already prepared by openQA)
    if (script_run("getent passwd $username") != 0) {
        assert_script_run "useradd -m $username -c '$realname'";
        assert_script_run "echo $username:$password | chpasswd";
    }

    ensure_serialdev_permissions;

    my $console = select_console 'user-console';
    verify_user_info;
    enter_cmd "exit";
    $console->reset();

    select_console 'root-console';
    if ($lang ne 'en_US') {
        assert_script_run("sed -ie '/KEYMAP=/s/=.*/=us/' /etc/vconsole.conf");
    }

    # openSUSE JeOS has SWAP mounted as LABEL instead of UUID until kiwi 9.19.0, so tw and Leap 15.2+ are fine
    verify_mounts unless is_leap('<15.2') && is_aarch64;
}

sub test_flags {
    return {fatal => 1};
}

1;
