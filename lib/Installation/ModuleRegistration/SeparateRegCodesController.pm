# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Registration Code dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleRegistration::SeparateRegCodesController;
use strict;
use warnings;
use Installation::ModuleRegistration::SeparateRegCodesPage;
use Installation::Popups::ImportUntrustedGnuPGKey;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SeparateRegCodesPage} = Installation::ModuleRegistration::SeparateRegCodesPage->new({app => YuiRestClient::get_app()});
    $self->{ImportUntrustedGnuPGKey} = Installation::Popups::ImportUntrustedGnuPGKey->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_module_regcode_page {
    my ($self) = @_;
    die "Extension and Module Registration Codes page" unless $self->{SeparateRegCodesPage}->is_shown();
    return $self->{SeparateRegCodesPage};
}

sub get_untrusted_GPG_popup {
    my ($self) = @_;
    die "Untrusted GPG key popup is not displayed" unless $self->{ImportUntrustedGnuPGKey}->is_shown();
    return $self->{ImportUntrustedGnuPGKey};
}

sub wait_for_separate_regcode {
    my ($self, $args) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{SeparateRegCodesPage}->is_shown({timeout => 0});
    }, %$args);
}

sub add_separate_registration_code {
    my ($self, $addon, $regcode) = @_;
    $self->get_module_regcode_page()->set_regcode($addon, $regcode);
    $self->get_module_regcode_page()->press_next();
}

sub trust_gnupg_key {
    my ($self) = @_;
    $self->get_untrusted_GPG_popup()->press_trust();
}

1;
