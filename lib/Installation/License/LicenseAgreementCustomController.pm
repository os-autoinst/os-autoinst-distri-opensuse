# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for License Agreement custom
# page in YaST Firstboot
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::LicenseAgreementCustomController;
use parent 'Installation::License::AbstractLicenseAgreementController';
use strict;
use warnings;
use Installation::License::LicenseAgreementExplicitPage;

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementExplicitPage->new({
            app => YuiRestClient::get_app(),
            chb_accept_license_filter => {id => '"eula_//usr/share/firstboot/custom"'},
            cmb_language_filter => {id => '"license_language_//usr/share/firstboot/custom"'},
            rct_eula_filter => {id => '"welcome_text_//usr/share/firstboot/custom"'}});
    return $self;
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->check_accept_license();
    $self->get_license_agreement_page()->press_next();
}

1;
