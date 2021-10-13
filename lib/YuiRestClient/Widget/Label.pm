# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Label;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';

sub text {
    my ($self) = @_;
    return $self->property('text');
}

1;
