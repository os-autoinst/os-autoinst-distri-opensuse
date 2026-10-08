# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verify the CZ keyboard layout and locale configuration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'basetest';
use testapi;

sub run {
    # Clear leftover characters from the previous test module
    send_key 'ctrl-u';

    enter_cmd 'root';
    assert_screen 'password-prompt', 10;

    enter_cmd 'nots#cr#t';
    assert_screen 'root-console-prompt', 15;

    # Switch keyboard layout to US
    # Note: 'y' and 'z' are swapped on CZ layout, so we send 'loadkezs us'
    enter_cmd 'loadkezs us';

    enter_cmd 'rpm -q glibc-locale';
    assert_screen 'glibc-locale-installed', 15;

    enter_cmd 'cat /etc/locale.conf';
    assert_screen 'locale-configuration-cz', 15;

    enter_cmd 'rpm -qa --provides | grep "locale\(.*:cs\)" | xargs -n1 rpm -q --whatprovides | sort -u';
    assert_screen 'lang-package', 15;
}

sub post_fail_hook {
    save_screenshot;
}

1;
