# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Registration dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Registration::RegistrationController;
use strict;
use warnings;
use Installation::Registration::RegistrationPage;
use Installation::Popups::YesNoPopup;
use Installation::Popups::ImportPopup;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{RegistrationPage} = Installation::Registration::RegistrationPage->new({app => YuiRestClient::get_app()});
    $self->{UseUpdateReposPopup} = Installation::Popups::YesNoPopup->new({
            app => YuiRestClient::get_app()});
    $self->{SkipRegistrationPopup} = Installation::Popups::OKPopup->new({
            app => YuiRestClient::get_app()});
    $self->{ImportPopup} = Installation::Popups::ImportPopup->new({
            app => YuiRestClient::get_app()});
    return $self;
}

sub get_registration_page {
    my ($self) = @_;
    die "Registration page is not displayed" unless $self->{RegistrationPage}->is_shown();
    return $self->{RegistrationPage};
}

sub get_enable_update_repositories_popup {
    my ($self) = @_;
    die "Update repositories popup is not displayed" unless $self->{UseUpdateReposPopup}->is_shown();
    return $self->{UseUpdateReposPopup};
}

sub get_skip_registration_popup {
    my ($self) = @_;
    die "Warning for skipping registration is not displayed" unless $self->{SkipRegistrationPopup}->is_shown();
    return $self->{SkipRegistrationPopup};
}

sub get_import_popup {
    my ($self) = @_;
    die "Popup for Trust&Import is not displayed" unless $self->{ImportPopup}->is_shown();
    return $self->{ImportPopup};
}

sub register_via_scc {
    my ($self, $args) = @_;
    $self->get_registration_page->enter_email($args->{email}) if $args->{email};
    $self->get_registration_page->enter_reg_code($args->{reg_code});
    $self->get_registration_page->press_next();
}

sub register_via_rmt {
    my ($self, $args) = @_;
    $self->get_registration_page->select_rmt_registration();
    $self->get_registration_page->enter_local_server($args->{server});
    $self->get_registration_page->press_next();
}

sub skip_registration {
    my ($self) = @_;
    $self->get_registration_page->select_skip_registration();
    $self->get_skip_registration_popup->press_ok();
    $self->get_registration_page->press_next();
}

sub enable_update_repositories {
    my ($self) = @_;
    $self->get_enable_update_repositories_popup()->press_yes();
}

sub trust_and_import {
    my ($self) = @_;
    $self->get_import_popup()->press_import();
}

1;
