# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) SLE 16 distribution and
# provides access to its features.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Sle::16Latest;
use parent Distribution::Opensuse::AgamaDevel;
use strict;
use warnings FATAL => 'all';

1;
