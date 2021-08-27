# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for License Agreement Page
#          of the installer in SLE
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
            app           => YuiRestClient::get_app(),
            btn_ok_filter => {id => 'ok'}});
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementExplicitPage->new({
            app                      => YuiRestClient::get_app(),
            ch_accept_license_filter => {id => '"Y2Packager::Widgets::ProductLicenseConfirmation"'},
            cb_language_filter       => {id => '"simple_language_selection"'},
            rt_eula_filter           => {id => '"CWM::RichText"'}});
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
