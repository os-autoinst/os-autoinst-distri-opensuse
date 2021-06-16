# SUSE's openQA tests
#
# Copyright © 2019-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Formatting Options
# Page of Expert Partitioner that are unique for Libstorage. All the common
# methods are described in the parent class.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
