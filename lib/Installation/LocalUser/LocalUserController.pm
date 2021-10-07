# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
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
use Installation::Popups::YesNoPopup;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{LocalUserPage}       = Installation::LocalUser::LocalUserPage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordWarning} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_local_user_page {
    my ($self) = @_;
    die 'Local User page is not displayed' unless $self->{LocalUserPage}->is_shown();
    return $self->{LocalUserPage};
}

sub get_weak_password_warning {
    my ($self) = @_;
    return $self->{WeakPasswordWarning};
}

sub create_user {
    my ($self, %args) = @_;
    my $full_name = $args{full_name};
    my $username  = $args{username};
    my $password  = $args{password};
    $self->get_local_user_page()->enter_full_name($full_name);
    $self->get_local_user_page()->enter_username($username) if defined $username;
    $self->get_local_user_page()->enter_password($password);
    $self->get_local_user_page()->enter_confirm_password($password);
}

sub use_same_password_for_admin {
    my ($self) = @_;
    $self->get_local_user_page()->select_use_this_password_for_admin();
}

sub enable_automatic_login {
    my ($self) = @_;
    $self->get_local_user_page()->set_autologin(1);
}

sub disable_automatic_login {
    my ($self) = @_;
    $self->get_local_user_page()->set_autologin(0);
}

sub is_autologin {
    my ($self) = @_;
    $self->get_local_user_page()->has_autologin_checked();
}

sub is_use_same_password_for_admin {
    my ($self) = @_;
    $self->get_local_user_page()->has_use_same_password_for_admin_checked();
}

1;
