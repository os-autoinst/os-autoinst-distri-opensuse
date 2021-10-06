# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::RichText;

use strict;
use warnings;
use YuiRestClient::Action;

use parent 'YuiRestClient::Widget::Base';

sub text {
    my ($self) = @_;
    return $self->property('text');
}

sub activate_link {
    my ($self, $link) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $link);
}

1;
