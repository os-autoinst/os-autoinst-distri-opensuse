# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot SelfInstallation image for SLEM
# Maintainer: QA-C team <qa-c@suse.de>

use Mojo::Base qw(opensusebasetest);
use testapi;
use microos "microos_login";
use Utils::Architectures qw(is_aarch64);

sub run {
    my ($self) = @_;
    assert_screen 'selfinstall-screen', 180;
    send_key 'down' unless check_screen 'selfinstall-select-drive';
    assert_screen 'selfinstall-select-drive';
    send_key 'ret';
    assert_screen 'slem-selfinstall-overwrite-drive';
    send_key 'ret';
    # Use firmware boot manager of aarch64 to boot HDD
    $self->handle_uefi_boot_disk_workaround if is_aarch64;

    # workaround failed *kexec* execution on UEFI with SecureBoot
    assert_screen(['failed-to-kexec', 'linux-login-microos'], 240);
    if (get_var('UEFI') && match_has_tag('failed-to-kexec')) {
        eject_cd();
        record_soft_failure('bsc#1203896 - kexec fail in selfinstall with secureboot');
        send_key 'ret';
    }

    microos_login;
}

sub test_flags {
    return {fatal => 1};
}

1;
