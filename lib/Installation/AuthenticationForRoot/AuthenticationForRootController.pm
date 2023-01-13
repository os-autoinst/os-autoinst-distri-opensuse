# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Authentication
# for the System Administrator "root"
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::AuthenticationForRoot::AuthenticationForRootController;
use strict;
use warnings;
use Installation::AuthenticationForRoot::AuthenticationForRootPage;
use Installation::Popups::YesNoPopup;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AuthenticationForRootPage} = Installation::AuthenticationForRoot::AuthenticationForRootPage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordWarning} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_authentication_for_root_page {
    my ($self) = @_;
    die 'Authentication For Root page is not displayed' unless $self->{AuthenticationForRootPage}->is_shown();
    return $self->{AuthenticationForRootPage};
}

sub get_weak_password_warning {
    my ($self) = @_;
    return $self->{WeakPasswordWarning};
}

sub set_password {
    my ($self, $password) = @_;
    $self->get_authentication_for_root_page()->enter_password($password);
    $self->get_authentication_for_root_page()->enter_confirm_password($password);
}

1;
