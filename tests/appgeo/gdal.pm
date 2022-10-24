# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install gdal and perform tests
# Maintainer: Guillaume <guillaume@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    zypper_call 'in gdal';

    select_console 'user-console';
    validate_script_output("gdalinfo --formats", sub { m/BMP -raster-/ });
    # Check tif image
    validate_script_output("gdalinfo ~/data/geo/raster_sample.tif", sub { m/Coordinate System is:/ });
}

1;
