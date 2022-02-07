# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test containerd with nerdctl installation and usage
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use containers::utils;
use containers::container_images;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $engine = $self->containers_factory('containerd_nerdctl');

    # Run minimal runtime tests
    $engine->minimal_tests();
}

1;
