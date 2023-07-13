# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for License Agreement Page
#          of the installer in SLE
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::Sle::LicenseAgreementController;
use parent 'Installation::License::AbstractLicenseAgreementController';
use strict;
use warnings;
use Installation::License::AcceptLicensePopup;
use Installation::License::LicenseAgreementExplicitPage;
use YuiRestClient;

sub init {
    my ($self, $args) = @_;
    $self->{AcceptLicensePopup} = Installation::License::AcceptLicensePopup->new({
            app => YuiRestClient::get_app(),
            btn_ok_filter => {id => qr/ok_msg|ok/}});
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementExplicitPage->new({
            app => YuiRestClient::get_app(),
            chb_accept_license_filter => {id => '"Y2Packager::Widgets::ProductLicenseConfirmation"'},
            cmb_language_filter => {id => qr/Y2Country::Widgets::LanguageSelection|simple_language_selection/},
            rct_eula_filter => {id => '"CWM::RichText"'}});
    return $self;
}

sub get_accept_license_popup {
    my ($self) = @_;
    return $self->{AcceptLicensePopup};
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->check_accept_license();
    $self->get_license_agreement_page()->press_next();
}

sub proceed_without_explicit_agreement {
    my ($self) = @_;
    $self->get_license_agreement_page()->press_next();
    return $self->get_accept_license_popup();
}

1;
