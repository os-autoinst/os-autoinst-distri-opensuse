# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install gdal and perform tests
# Maintainer: Guillaume <guillaume@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    zypper_call 'in gdal';

    select_console 'user-console';
    validate_script_output("gdalinfo --formats", sub { m/BMP -raster-/ });
    # Check tif image
    validate_script_output("gdalinfo ~/data/geo/raster_sample.tif", sub { m/Coordinate System is:/ });
}

1;
