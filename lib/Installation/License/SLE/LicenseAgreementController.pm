# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for License Agreement Page
#          of the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::SLE::LicenseAgreementController;
use strict;
use warnings;
use Installation::License::SLE::AcceptLicensePopup;
use Installation::License::SLE::LicenseAgreementPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AcceptLicensePopup}   = Installation::License::SLE::AcceptLicensePopup->new({app => YuiRestClient::get_app()});
    $self->{LicenseAgreementPage} = Installation::License::SLE::LicenseAgreementPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->check_accept_license();
    $self->proceed_to_next_page();

    return $self;
}

sub get_license_agreement_page {
    my ($self) = @_;
    die "License Agreement Page is not displayed" unless $self->{LicenseAgreementPage}->is_shown();
    return $self->{LicenseAgreementPage};
}

sub get_accept_license_popup {
    my ($self) = @_;
    die "Accept License Agreement popup is not displayed" unless $self->{AcceptLicensePopup}->is_shown();
    return $self->{AcceptLicensePopup};
}

sub proceed_to_next_page {
    my ($self) = @_;
    $self->get_license_agreement_page()->press_next();
}

sub process_accept_license_pop_up {
    my ($self) = @_;
    $self->get_accept_license_popup()->press_ok();
    return $self->get_license_agreement_page()->is_shown();
}

1;
