# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Formatting Options
# Page of Expert Partitioner, which are unique for LibstorageNG. All the common
# methods are described in the parent class.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::FormattingOptionsPage';

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next($self->FORMATTING_OPTIONS_PAGE);
}

1;
