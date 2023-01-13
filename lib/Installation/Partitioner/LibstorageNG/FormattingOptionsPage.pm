# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Formatting Options
# Page of Expert Partitioner, which are unique for LibstorageNG. All the common
# methods are described in the parent class.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::FormattingOptionsPage';

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next($self->FORMATTING_OPTIONS_PAGE);
}

1;
