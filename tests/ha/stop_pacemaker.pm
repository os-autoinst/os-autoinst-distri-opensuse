# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ha-cluster-bootstrap
# Summary: stop pacemaker
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use Utils::Systemd qw(systemctl);

sub run {
    systemctl 'stop pacemaker';
}

1;
