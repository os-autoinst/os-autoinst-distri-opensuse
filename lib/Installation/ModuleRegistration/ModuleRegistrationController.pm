# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Registration dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ModuleRegistration::ModuleRegistrationController;
use strict;
use warnings;
use Installation::ModuleRegistration::ModuleRegistrationPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ModuleRegistrationPage} = Installation::ModuleRegistration::ModuleRegistrationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_module_registration_page {
    my ($self) = @_;
    die "Extension and Module Selection page is not displayed" unless $self->{ModuleRegistrationPage}->is_shown();
    return $self->{ModuleRegistrationPage};
}

sub register_module {
    my ($self, $module) = @_;
    $self->get_module_registration_page()->register_module($module);
    $self->get_module_registration_page()->press_next();
}

sub register_extension_and_modules {
    my ($self, $modules) = @_;
    $self->get_module_registration_page()->register_extension_and_modules($modules);
    $self->get_module_registration_page()->press_next();
}

sub skip_registration {
    my ($self) = @_;
    $self->get_module_registration_page()->press_next();
}

sub view_development_versions {
    my ($self) = @_;
    $self->get_module_registration_page()->uncheck_hide_development_versions();
}

sub get_registered_modules {
    my ($self) = @_;
    return $self->get_module_registration_page()->get_registered_modules();
}

sub get_modules {
    my ($self) = @_;
    return $self->get_module_registration_page()->get_modules();
}

1;
