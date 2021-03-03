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
use Installation::License::SLE::LicenseAgreementPage;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{LicenseAgreementPage} = Installation::License::SLE::LicenseAgreementPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_license_agreement_page {
    my ($self) = @_;
    die "License Agreement Page is not displayed" unless $self->{LicenseAgreementPage}->is_shown();
    return $self->{LicenseAgreementPage};
}

1;
