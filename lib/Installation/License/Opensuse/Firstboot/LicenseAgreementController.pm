# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for License Agreement page
#          in YaST Firstboot for openSUSE.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::Opensuse::Firstboot::LicenseAgreementController;
use parent 'Installation::License::AbstractLicenseAgreementController';
use strict;
use warnings;
use Installation::License::LicenseAgreementPage;

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementPage->new({
            app => YuiRestClient::get_app(),
            cmb_language_filter => {id => '"license_language_/usr/share/licenses/product/base/"'},
            rct_eula_filter => {id => '"welcome_text_/usr/share/licenses/product/base/"'}});
    return $self;
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->press_next();
}

1;
