# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for License Page
#          of the installer in openSUSE
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::Opensuse::LicenseAgreementController;
use parent 'Installation::License::AbstractLicenseAgreementController';
use strict;
use warnings;
use Installation::License::LicenseAgreementPage;
use YuiRestClient;

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementPage->new({
            app => YuiRestClient::get_app(),
            rct_eula_filter => {id => '"CWM::RichText"'}});
    return $self;
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->press_next();
}

1;
