# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot SelfInstallation image for SLEM
# Maintainer: QA-C team <qa-c@suse.de>

use Mojo::Base qw(opensusebasetest);
use testapi;
use microos "microos_login";

sub run {
    assert_screen 'selfinstall-select-drive';
    send_key 'ret';
    assert_screen 'slem-selfinstall-overwrite-drive';
    send_key 'ret';
    microos_login;
}

sub test_flags {
    return {fatal => 1};
}

1;
