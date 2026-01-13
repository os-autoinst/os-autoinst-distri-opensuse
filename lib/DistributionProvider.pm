# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: A library that provides the certain distribution depending on the
# version of the product that is specified for a Test Suite.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package DistributionProvider;
use strict;
use warnings FATAL => 'all';
use version_utils;

use Distribution::Sle::AgamaDevel;
use Distribution::Sle::16Latest;
use Distribution::Sle::15sp0;
use Distribution::Sle::15sp2;
use Distribution::Sle::15_current;
use Distribution::Sle::12;
use Distribution::Opensuse::Leap::42;
use Distribution::Opensuse::Leap::15;
use Distribution::Opensuse::Leap::16Latest;
use Distribution::Opensuse::Tumbleweed;
use Distribution::Opensuse::AgamaTumbleweed;
use Distribution::Opensuse::AgamaDevel;

use testapi;

=head2 provide

  provide();

Returns the certain distribution depending on the version of the product.

If there is no matched version, then returns Tumbleweed as the default one.

=cut

sub provide {
    return Distribution::Sle::AgamaDevel->new() if is_sle('16+') && get_var('FLAVOR', '') =~ /agama-installer/;
    return Distribution::Sle::16Latest->new() if is_sle('16+');
    return Distribution::Sle::15_current->new() if (is_sle('>=15-sp3') || is_sle_micro);
    return Distribution::Sle::15sp2->new() if is_sle('>15');
    return Distribution::Sle::15sp0->new() if is_sle('=15');
    return Distribution::Sle::12->new() if is_sle('12+');
    return Distribution::Opensuse::Leap::16Latest->new() if is_leap('16.0+');
    return Distribution::Opensuse::Leap::15->new() if is_leap('15.0+');
    return Distribution::Opensuse::Leap::42->new() if is_leap('42.0+');
    return Distribution::Opensuse::AgamaDevel->new() if is_opensuse() && get_var('VERSION', '') =~ /agama/;
    return Distribution::Opensuse::AgamaTumbleweed->new() if is_opensuse() && is_agama();
    return Distribution::Opensuse::Tumbleweed->new();
}

1;
