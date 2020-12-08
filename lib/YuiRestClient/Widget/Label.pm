# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
