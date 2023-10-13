# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package main_ltp_loader;
use strict;
use warnings;
use base 'Exporter';
use Exporter;

our @EXPORT_OK = qw(load_kernel_tests);

# Isolate the loading of LTP tests because they often rely on newer features
# not present on all workers. If they are isolated then only the LTP tests
# will fail to load when there is a version mismatch instead of all tests.
local $@;
eval "use main_ltp 'load_kernel_tests'";
if ($@) {
    bmwqemu::fctwarn("Failed to load main_ltp.pm:\n$@", 'main_ltp.pm');
    eval q%{
        sub load_kernel_tests {
            die "Can not run kernel tests because evaluating main_ltp.pm failed"
                if is_kernel_test;
            return 0;
        }
    %;
}

1;
