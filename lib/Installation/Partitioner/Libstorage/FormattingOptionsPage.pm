# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Formatting Options
# Page of Expert Partitioner that are unique for Libstorage. All the common
# methods are described in the parent class.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::FormattingOptionsPage';

sub press_finish {
    my ($self) = @_;
    assert_screen($self->FORMATTING_OPTIONS_PAGE);
    send_key('alt-f');
}

1;
