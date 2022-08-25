# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Registration Code dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ModuleRegistration::ModuleRegCodeController;
use strict;
use warnings;
use Installation::ModuleRegistration::ModuleRegCodePage;
use Installation::Popups::ImportUntrustedGnuPGKey;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ModuleRegCodePage} = Installation::ModuleRegistration::ModuleRegCodePage->new({app => YuiRestClient::get_app()});
    $self->{ImportUntrustedGnuPGKey} = Installation::Popups::ImportUntrustedGnuPGKey->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_module_regcode_page {
    my ($self) = @_;
    die "Extension and Module Registration Codes page" unless $self->{ModuleRegCodePage}->is_shown();
    return $self->{ModuleRegCodePage};
}

sub get_untrusted_GPG_popup {
    my ($self) = @_;
    die "Untrusted GPG key popup is not displayed" unless $self->{ImportUntrustedGnuPGKey}->is_shown();
    return $self->{ImportUntrustedGnuPGKey};
}

sub wait_regcode_page {
    my ($self, $args) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{ModuleRegCodePage}->is_shown({timeout => 0});
    }, %$args);
}

sub add_separate_registration_code {
    my ($self, $regcode, $timeout) = @_;
    $self->wait_regcode_page({timeout => $timeout, interval => 2,
            message => 'Page to insert module registration code did not appear'});
    $self->get_module_regcode_page()->set_regcode($regcode);
    $self->get_module_regcode_page()->press_next();
}

sub trust_gnupg_key {
    my ($self) = @_;
    $self->get_untrusted_GPG_popup()->press_trust();
}

1;
