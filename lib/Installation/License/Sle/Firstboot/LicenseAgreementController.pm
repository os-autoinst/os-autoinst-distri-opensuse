# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for License Agreement page
#          in YaST Firstboot for SLE.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::Sle::Firstboot::LicenseAgreementController;
use parent 'Installation::License::Sle::LicenseAgreementController';
use strict;
use warnings;
use Installation::License::LicenseAgreementExplicitPage;

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::LicenseAgreementExplicitPage->new({
            app                      => YuiRestClient::get_app(),
            ch_accept_license_filter => {id => '"eula_/usr/share/licenses/product/base/"'},
            cb_language_filter       => {id => '"license_language_/usr/share/licenses/product/base/"'},
            rt_eula_filter           => {id => '"welcome_text_/usr/share/licenses/product/base/"'}});
    return $self;
}

1;
