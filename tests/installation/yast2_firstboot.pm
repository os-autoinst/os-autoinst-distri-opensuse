# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Utilize OS using YaST2 Firstboot module
# Doc: https://en.opensuse.org/YaST_Firstboot
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "y2logsstep";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use installation_user_settings qw(await_password_check enter_userinfo enter_rootinfo);
use version_utils qw(is_sle is_opensuse);

sub language_and_keyboard {
    my $shortcuts = {
        l => 'lang',
        k => 'keyboard'
    };
    assert_screen 'lang_and_keyboard';
    mouse_hide(1);
    foreach (sort keys %${shortcuts}) {
        send_key 'alt-' . $_;
        assert_screen $shortcuts->{$_} . '_selected';
        send_key_until_needlematch 'expanded_list', 'spc', 5, 7;
        wait_screen_change(sub { send_key 'ret'; }, 5);
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub license {
    my $self = shift;
    return unless is_sle('>=12-sp4');
    assert_screen('license-agreement');
    $self->verify_license_has_to_be_accepted;
    $self->accept_license;
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
    # Workaround license checkbox
    assert_screen(qw(license-agreement inst-timezone));
    if (match_has_tag('license-agreement')) {
        record_soft_failure 'bsc#1131327 License checkbox was cleared! Re-check again!';
        send_key 'alt-a';
        assert_screen('license-agreement-accepted');
        wait_screen_change(sub { send_key $cmd{next}; }, 7);
    }
    elsif (match_has_tag('inst-timezone')) {
        return;
    }
    # End of WA
}

sub welcome {
    assert_screen 'welcome';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub clock_and_timezone {
    assert_screen 'inst-timezone';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub user_setup {
    my $is_not_shared_passwd = shift;
    assert_screen 'local_user';
    enter_userinfo(username => 'y2_firstboot_tester');
    if (defined($is_not_shared_passwd)) {
        send_key 'alt-t' if (is_opensuse);
    }
    else {
        send_key 'alt-t' if (is_sle('>=12-sp4'));
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
    await_password_check;
    wait_screen_change(sub { send_key $cmd{next}; }, 7) unless defined($is_not_shared_passwd);
}

sub root_setup {
    assert_screen 'root_user';
    enter_rootinfo;
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub run {
    my $self = shift;
    language_and_keyboard;
    welcome;
    $self->license;
    clock_and_timezone;
    user_setup(1);
    root_setup;
    assert_screen 'installation_completed';
    send_key $cmd{finish};
    assert_screen 'displaymanager';
}

1;
