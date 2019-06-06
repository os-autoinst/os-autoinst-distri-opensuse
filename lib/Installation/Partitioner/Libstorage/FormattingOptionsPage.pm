# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: TODO
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
