# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Role Page, that are
# common for all the versions of the page (e.g. for both Libstorage and
# Libstorage-NG).
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::RolePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ROLE_PAGE => 'partition-role'
};

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(ROLE_PAGE);
}

1;
