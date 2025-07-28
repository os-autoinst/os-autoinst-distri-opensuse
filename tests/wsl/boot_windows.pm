# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot installed MS Windows from image
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'windowsbasetest';
use testapi;

sub run {
    my ($self) = @_;

    $self->select_windows_in_grub2;
    $self->wait_boot_windows;
}

1;
