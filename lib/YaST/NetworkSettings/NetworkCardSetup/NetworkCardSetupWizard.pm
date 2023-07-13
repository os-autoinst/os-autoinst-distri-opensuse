# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class is a parent for all Pages of Network Card Setup Wizard.
# Introduces accessing methods to the elements that are common for all steps
# of the Wizard.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
}

sub press_next {
    my ($self, $page_needle) = @_;
    assert_screen($page_needle);
    send_key('alt-n');
}

1;
