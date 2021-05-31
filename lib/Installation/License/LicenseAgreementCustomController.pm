# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for License Agreement custom
# page in YaST Firstboot
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::LicenseAgreementCustomController;
use parent 'Installation::License::AbstractLicenseAgreementController';
use strict;
use warnings;
use Installation::License::LicenseAgreementExplicitPage;

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementExplicitPage->new({
            app                      => YuiRestClient::get_app(),
            ch_accept_license_filter => {id => '"eula_//usr/share/firstboot/custom"'},
            cb_language_filter       => {id => '"license_language_//usr/share/firstboot/custom"'},
            rt_eula_filter           => {id => '"welcome_text_//usr/share/firstboot/custom"'}});
    return $self;
}

sub accept_license {
    my ($self) = @_;
    $self->get_license_agreement_page()->check_accept_license();
    $self->get_license_agreement_page()->press_next();
}

1;
