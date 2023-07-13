# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test containerd with nerdctl installation and usage
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use serial_terminal 'select_serial_terminal';
use containers::utils 'runtime_smoke_tests';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $engine = $self->containers_factory('containerd_nerdctl');

    # Run runtime smoke tests
    runtime_smoke_tests(runtime => $engine);
}

1;
