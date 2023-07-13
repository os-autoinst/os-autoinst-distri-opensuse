# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Registration dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleRegistration::ModuleRegistrationInstallationReportController;
use strict;
use warnings;
use Installation::ModuleRegistration::ModuleRegistrationInstallationReportPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ModuleRegistrationInstallationReportPage} = Installation::ModuleRegistration::ModuleRegistrationInstallationReportPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_module_registration_installation_report_page {
    my ($self) = @_;
    die "Module Registration Installation Report page is not displayed" unless $self->{ModuleRegistrationInstallationReportPage}->is_shown();
    return $self->{ModuleRegistrationInstallationReportPage};
}

sub press_finish {
    my ($self) = @_;
    $self->get_module_registration_installation_report_page->press_next();
}

1;
