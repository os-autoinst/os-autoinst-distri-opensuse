# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::RadioButton;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub select {
    my ($self) = @_;

    return $self->action(action => YuiRestClient::Action::YUI_SELECT);
}

sub is_selected {
    my ($self) = @_;
    $self->property('value');
}

1;
