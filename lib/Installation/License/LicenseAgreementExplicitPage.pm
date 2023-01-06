# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Page to handle License Agreement page with checkbox to
# explicitly accept it
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::LicenseAgreementExplicitPage;
use parent 'Installation::License::LicenseAgreementPage';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{chb_accept_license} = $self->{app}->checkbox($args->{chb_accept_license_filter});
    return $self;
}

sub check_accept_license {
    my ($self) = @_;
    return $self->{chb_accept_license}->check();
}

1;
