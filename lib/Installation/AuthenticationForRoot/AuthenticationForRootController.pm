# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Authentication
# for the System Administrator "root"
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AuthenticationForRoot::AuthenticationForRootController;
use strict;
use warnings;
use Installation::AuthenticationForRoot::AuthenticationForRootPage;
use Installation::Warnings::ConfirmationWarning;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AuthenticationForRootPage} = Installation::AuthenticationForRoot::AuthenticationForRootPage->new({app => YuiRestClient::get_app()});
    $self->{TooSimplePasswordWarning}  = Installation::Warnings::ConfirmationWarning->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_authentication_for_root_page {
    my ($self) = @_;
    die 'Authentication For Root page is not displayed' unless $self->is_authentication_for_root_page_shown();
    return $self->{AuthenticationForRootPage};
}

sub is_authentication_for_root_page_shown {
    my ($self) = @_;
    return $self->{AuthenticationForRootPage}->is_shown();
}

sub get_too_simple_password_warning {
    my ($self) = @_;
    if ($self->{TooSimplePasswordWarning}->text() !~ /The password is too simple/) {
        die 'Too simple password warning is not displayed';
    }
    return $self->{TooSimplePasswordWarning};
}

sub add_authentication_using_simple_password {
    my ($self, $args) = @_;
    $self->get_authentication_for_root_page()->setup($args);
    $self->get_authentication_for_root_page()->press_next();
    $self->get_too_simple_password_warning()->press_yes();
    YuiRestClient::Wait::wait_until(object => sub {
            return !$self->is_authentication_for_root_page_shown();
    }, timeout => 30);
}

1;
