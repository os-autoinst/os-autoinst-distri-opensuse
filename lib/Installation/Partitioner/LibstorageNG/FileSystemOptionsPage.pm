# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for File System Options
# Page in Guided Setup.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::FileSystemOptionsPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::AbstractPage';

use constant {
    FILE_SYSTEM_OPTIONS_PAGE => 'inst-filesystem-options'
};

sub press_next {
    my ($self) = @_;
    assert_screen(FILE_SYSTEM_OPTIONS_PAGE);
    $self->get_navigation_panel()->press_next();
}

1;
