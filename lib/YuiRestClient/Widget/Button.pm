# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Button;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub click {
    my ($self) = @_;

    return $self->action(action => YuiRestClient::Action::YUI_PRESS);
}

sub is_enabled {
    my ($self) = @_;
    my $is_enabled = $self->property('enabled');
    return !defined $is_enabled || $is_enabled;
}

1;
