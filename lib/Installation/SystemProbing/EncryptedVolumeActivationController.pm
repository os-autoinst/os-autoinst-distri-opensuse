# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for YaST Encrypted Volume module.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::SystemProbing::EncryptedVolumeActivationController;
use strict;
use warnings;
use YuiRestClient;
use Installation::SystemProbing::EncryptedVolumeActivationPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{EncryptedVolumeActivationPage} = Installation::SystemProbing::EncryptedVolumeActivationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_encrypted_volume_activation_page {
    my ($self) = @_;
    die "Encrypted Volume Activation Page is not shown" unless $self->{EncryptedVolumeActivationPage}->is_shown();
    return $self->{EncryptedVolumeActivationPage};
}

sub enter_volume_encryption_password {
    my ($self, $encryption_password) = @_;
    $self->get_encrypted_volume_activation_page->enter_password($encryption_password);
}

sub accept_password {
    my ($self) = @_;
    $self->get_encrypted_volume_activation_page->press_ok();
}

sub cancel {
    my ($self) = @_;
    $self->get_encrypted_volume_activation_page->press_cancel();
}

1;
