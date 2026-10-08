# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: https://docs.gnuhealth.org/mygnuhealth
# Maintainer: Oliver Kurz <okurz@suse.de>

use Mojo::Base 'x11test', -signatures;
use testapi;

sub run {
    ensure_installed('mygnuhealth');
    x11_start_program('mygnuhealth');
    send_key 'alt-f4';
}

1;
