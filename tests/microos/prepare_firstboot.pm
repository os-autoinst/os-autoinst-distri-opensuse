# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable firstboot as required by openQA testsuite
# Maintainer: qa-c

use Mojo::Base 'opensusebasetest';;
use testapi;
use version_utils qw(is_sle);
use Utils::Backends qw(is_generalhw);

sub run {
    my ($self) = @_;

    my $default_password = 'linux';
    my $distripassword = $testapi::password;

    #my $is_generalhw_via_ssh = is_generalhw && !defined(get_var('GENERAL_HW_VNC_IP'));
    #
    #if (get_var('GENERAL_HW_VIDEO_STREAM_URL')) {
    #    select_console('sut');
    #    assert_screen('linux-login', 200);
    #
    #    if (get_var('GENERAL_HW_KEYBOARD_URL')) {
    #        enter_cmd("root", wait_still_screen => 5);
    #        enter_cmd("$testapi::password", wait_still_screen => 5);
    #        assert_screen('text-logged-in-root');
    #    }
    #}
    #sleep(100);
    wait_serial(qr/login:\s*$/i);
    select_console('root-ssh');
}

1;
