# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use strict;

# test for curl RC4 and SEED ciphers with fips enabled
sub run() {
    my $self = shift;
    select_console 'root-console';
    script_output "curl --ciphers RC4,SEED -v https://eu.httpbin.org/get | tee";
    validate_script_output "curl --ciphers RC4,SEED -v https://eu.httpbin.org/get 2>&1 | tee", sub { m/failed setting cipher/ };
    validate_script_output "rpm -q curl libcurl4",                                             sub { m/curl-.*/ };
}

1;
# vim: set sw=4 et:
