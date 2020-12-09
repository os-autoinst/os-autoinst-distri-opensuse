# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::CheckBox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub check {
    my ($self, $item) = @_;
    $self->action(action => YuiRestClient::Action::YUI_CHECK, value => $item);
}

sub is_checked {
    my ($self) = @_;
    $self->property('value');
}

sub toggle {
    my ($self, $item) = @_;
    $self->action(action => YuiRestClient::Action::YUI_TOGGLE, value => $item);
}

sub uncheck {
    my ($self, $item) = @_;
    $self->action(action => YuiRestClient::Action::YUI_UNCHECK, value => $item);
}

1;
