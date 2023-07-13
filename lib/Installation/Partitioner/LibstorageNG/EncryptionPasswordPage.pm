# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: The class introduces all accessing methods for Encryption Password.
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::EncryptionPasswordPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ENCRYPT_PASSWORD_PAGE => 'encrypt_password_page',
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        enter_password_shortcut => $args->{enter_password_shortcut},
        verify_password_shortcut => $args->{verify_password_shortcut}
    }, $class;
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(ENCRYPT_PASSWORD_PAGE);
}

sub assert_password_page {
    my ($self) = @_;
    assert_screen(ENCRYPT_PASSWORD_PAGE);
}

sub enter_password {
    my ($self) = @_;
    send_key($self->{enter_password_shortcut});
    type_password();
}

sub enter_password_verification {
    my ($self) = @_;
    send_key($self->{verify_password_shortcut});
    type_password();
}

1;
