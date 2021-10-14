# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::CheckBox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub check {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_CHECK);
}

sub is_checked {
    my ($self) = @_;
    $self->property('value');
}

sub toggle {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_TOGGLE);
}

sub uncheck {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_UNCHECK);
}

1;
