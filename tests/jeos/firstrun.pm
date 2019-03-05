# SUSE's openQA tests
#
# Copyright © 2015-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure JeOS
# Maintainer: Ciprian Cret <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';
use utils qw(assert_screen_with_soft_timeout ensure_serialdev_permissions);

sub post_fail_hook {
    assert_script_run('timedatectl');
    assert_script_run('locale');
    assert_script_run('cat /etc/vconsole.conf');
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

sub run {
    my $lang = is_sle('15+') ? 'en_US' : get_var('JEOSINSTLANG', 'en_US');

    my %keylayout_key = ('en_US' => 'e', 'de_DE' => 'd');
    # For 'en_US' pick 'en_US', for 'de_DE' select 'de_DE'
    my %locale_key = ('en_US' => 'e', 'de_DE' => 'd');
    # For 'en_US' pick 'UTC', for 'de_DE' select 'Europe/Berlin'
    my %tz_key = ('en_US' => 'u', 'de_DE' => 'e');

    # Select locale
    assert_screen 'jeos-locale', 300;
    # Without this 'ret' sometimes won't get to the dialog
    wait_still_screen;
    send_key_until_needlematch "jeos-system-locale-$lang", $locale_key{$lang}, 50;
    send_key 'ret';

    # Select language
    send_key_until_needlematch "jeos-keylayout-$lang", $keylayout_key{$lang}, 30;
    send_key 'ret';

    # Accept license
    if (is_sle) {
        if (check_screen 'jeos-license', 60) {
            send_key 'ret';
            assert_screen 'jeos-doyouaccept';
            send_key 'ret';
        }
        else {
            record_soft_failure 'bsc#1127166 - License moved to another location';
        }
    }

    # Select timezone
    send_key_until_needlematch "jeos-timezone-$lang", $tz_key{$lang}, 10;
    send_key 'ret';

    # Enter password
    assert_screen 'jeos-root-password';
    type_password;
    send_key 'ret';

    # Confirm password
    assert_screen 'jeos-confirm-root-password';
    type_password;
    send_key 'ret';

    if (is_sle) {
        assert_screen 'jeos-please-register';
        send_key 'ret';
    }

    # Our current Hyper-V host and it's spindles are quite slow. Especially
    # when there are more jobs running concurrently. We need to wait for
    # various disk optimizations and snapshot enablement to land.
    # Meltdown/Spectre mitigations makes this even worse.
    assert_screen_with_soft_timeout('linux-login', timeout => 1000, soft_timeout => 300, bugref => 'bsc#1077007');

    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);

    type_string('1234%^&*()qwerty');
    assert_screen("keymap-letter-data-$lang");
    send_key('ctrl-u');
    # Set 'us' keyboard as openQA can't operate with non-us keyboard layouts
    if ($lang ne 'en_US') {
        # With the foreign keyboard, type 'loadkeys us'
        my %loadkeys_reset = ('de_DE' => 'loadkezs us');
        type_string("$loadkeys_reset{$lang}\n");
        wait_still_screen;
    }
    # Manually configure root-console as we skipped some parts in root-console's activation
    $testapi::distri->set_standard_prompt('root');
    assert_script_run('setterm -blank 0');

    verify_user_info(user_is_root => 1);

    # Create user account
    assert_script_run "useradd -m $username -c '$realname'";
    assert_script_run "echo $username:$password | chpasswd";

    ensure_serialdev_permissions;

    select_console 'user-console';
    verify_user_info;

    select_console 'root-console';
    if ($lang ne 'en_US') {
        assert_script_run("sed -ie '/KEYMAP=/s/=.*/=us/' /etc/vconsole.conf");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
