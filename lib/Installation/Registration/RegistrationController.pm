# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Registration dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Registration::RegistrationController;
use strict;
use warnings;
use Installation::Registration::RegistrationPage;
use Installation::Warnings::ConfirmationWarning;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{RegistrationPage}    = Installation::Registration::RegistrationPage->new({app => YuiRestClient::get_app()});
    $self->{UseUpdateReposPopup} = Installation::Warnings::ConfirmationWarning->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_registration_page {
    my ($self) = @_;
    die "Registration page is not displayed" unless $self->{RegistrationPage}->is_shown();
    return $self->{RegistrationPage};
}

sub get_enable_update_repositories_popup {
    my ($self) = @_;
    die "Update repositories popup is not displayed"               unless $self->{UseUpdateReposPopup}->is_shown();
    die "Update repositories popup contains an unexpected message" unless (
        $self->{UseUpdateReposPopup}->text() =~ /The registration server offers update repos.*/);
    return $self->{UseUpdateReposPopup};
}

sub register_via_scc {
    my ($self, $args) = @_;
    $self->get_registration_page->enter_email($args->{email}) if $args->{email};
    $self->get_registration_page->enter_reg_code($args->{reg_code});
    $self->get_registration_page->press_next();
}

sub enable_update_repositories {
    my ($self) = @_;
    $self->get_enable_update_repositories_popup()->press_yes();
}

1;
