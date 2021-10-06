# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Textbox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub set {
    my ($self, $value) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_ENTER_TEXT, value => $value);
}

sub value {
    my ($self) = @_;
    return $self->property('value');
}

1;
