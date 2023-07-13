# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class is a parent for all Installation Pages. Introduces
# accessing methods to the elements that are common for all the pages.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::WizardPage;
use strict;
use warnings FATAL => 'all';
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
