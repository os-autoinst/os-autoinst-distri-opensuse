# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup OS using YaST2 Firstboot wizard
# Doc: https://en.opensuse.org/YaST_Firstboot
# In this test module, each firstboot "client" is treated by its own
# function and functions are called by test data. Some of these
# functions are using POM (see ui-framework-documentation.md) in which
# case each client is treated as a page defined in lib/YaST/FIrstboot/

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_module_basetest';
use y2_logs_helper qw(accept_license verify_license_has_to_be_accepted);
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use installation_user_settings qw(await_password_check enter_userinfo enter_rootinfo);
use version_utils qw(is_sle is_opensuse);
use scheduler 'get_test_suite_data';

sub firstboot_language_keyboard {
    my $shortcuts = {
        l => 'lang',
        k => 'keyboard'
    };
    assert_screen('lang_and_keyboard', 60);
    mouse_hide(1);
    foreach (sort keys %${shortcuts}) {
        send_key 'alt-' . $_;
        wait_screen_change(sub { send_key 'ret' }) if check_var('DESKTOP', 'textmode');
        assert_screen $shortcuts->{$_} . '_selected';
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub firstboot_licenses {
    my ($self, $custom_needle) = @_;
    # default TO value was not sufficient
    assert_screen('license-agreement' . $custom_needle, 60);
    # Nothing to be accepted in opensuse
    if (is_sle || $custom_needle) {
        $self->verify_license_has_to_be_accepted;
        $self->accept_license;
    }
    send_key $cmd{next};
}

sub firstboot_welcome {
    my ($self, $custom_needle) = @_;
    my $firstboot = $testapi::distri->get_firstboot();
    assert_screen 'welcome' . $custom_needle;
    $firstboot->press_next();
}

sub firstboot_timezone {
    my $firstboot = $testapi::distri->get_firstboot();
    assert_screen 'inst-timezone';
    $firstboot->press_next();
}

sub firstboot_user {
    assert_screen 'local_user';
    enter_userinfo(username => get_var('YAST2_FIRSTBOOT_USERNAME'));
    # In opensuse, we expect autologin at first boot, not in SLE.
    wait_screen_change(sub { send_key 'alt-a'; },    7) if is_opensuse;
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
    await_password_check;
}

sub firstboot_root {
    assert_screen 'root_user', 60;
    enter_rootinfo;
}

sub firstboot_hostname {
    my $firstboot = $testapi::distri->get_firstboot();
    assert_screen 'hostname';
    $firstboot->press_next();
}

sub firstboot_registration {
    my $firstboot = $testapi::distri->get_firstboot();
    assert_screen 'system_registered';
    $firstboot->press_next();
}

sub firstboot_keyboard {
    my $firstboot = $testapi::distri->get_firstboot();
    save_screenshot;
    $firstboot->setup_keyboard();
}

sub firstboot_NTP {
    my $firstboot = $testapi::distri->get_firstboot();
    save_screenshot;
    $firstboot->setup_NTP();
}

sub firstboot_lan {
    my $firstboot = $testapi::distri->get_firstboot();
    save_screenshot;
    $firstboot->setup_LAN();
}

sub firstboot_finish {
    my ($self, $custom_needle) = @_;
    assert_screen 'installation_completed' . $custom_needle;    # Should now be "Configuration_completed". Kept for historical reasons.
    send_key $cmd{finish};
}

sub run {
    my $self = shift;
    YuiRestClient::connect_to_app();
    my $test_data     = get_test_suite_data();
    my $custom_needle = $test_data->{custom_control_file} ? "_custom" : undef;
    foreach my $client (@{$test_data->{clients}}) {
        # Make sure the subroutine called from test data exists
        die "Client '$client' is not defined in the module, please check test_data" unless defined(&{"$client"});
        my $client_method = \&{"$client"};
        $client_method->($self, $custom_needle);
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    # upload YaST2 Firstboot configuration file
    upload_logs('/etc/YaST2/firstboot.xml', log_name => "firstboot.xml.conf");
}

sub test_flags {
    return {fatal => 1};
}

1;
