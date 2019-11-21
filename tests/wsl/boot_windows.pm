# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot installed MS Windows from image
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'windowsbasetest';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;

    $self->select_windows_in_grub2;
    $self->wait_boot_windows;
}

1;
