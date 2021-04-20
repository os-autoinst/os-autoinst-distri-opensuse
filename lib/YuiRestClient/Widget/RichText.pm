# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
