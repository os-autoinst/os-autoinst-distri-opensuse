# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Generic setup of X11 session with stability improvements for
#   automated tests
# Maintainer: Oliver Kurz <okurz@suse.de>

use Mojo::Base 'x11test', -signatures;

sub run ($self) { $self->disable_key_repeat }

1;
