# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Local user dialog
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::LocalUser::LocalUserController;
use strict;
use warnings;
use Installation::LocalUser::LocalUserPage;
use Installation::Warnings::ConfirmationWarning;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{LocalUserPage}            = Installation::LocalUser::LocalUserPage->new({app => YuiRestClient::get_app()});
    $self->{TooSimplePasswordWarning} = Installation::Warnings::ConfirmationWarning->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_local_user_page {
    my ($self) = @_;
    die 'Local User page is not displayed' unless $self->is_local_user_page_shown();
    return $self->{LocalUserPage};
}

sub is_local_user_page_shown {
    my ($self) = @_;
    return $self->{LocalUserPage}->is_shown();
}

sub get_too_simple_password_warning {
    my ($self) = @_;
    if ($self->{TooSimplePasswordWarning}->text() !~ /The password is too simple/) {
        die 'Too simple password warning is not displayed';
    }
    return $self->{TooSimplePasswordWarning};
}

sub create_new_user_with_simple_password {
    my ($self, $args) = @_;
    $self->get_local_user_page()->setup($args);
    $self->get_local_user_page()->press_next();
    $self->get_too_simple_password_warning()->press_yes();
    YuiRestClient::Wait::wait_until(object => sub {
            return !$self->is_local_user_page_shown();
    }, timeout => 30);
}

1;
