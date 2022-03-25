# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: php8 php8-zlib
# Summary: Simple PHP8 code hosted locally
#   This test requires the Web and Scripting module on SLE.
# - Setup apache2 to use php8 modules
# - Run "curl http://localhost/index.php", check output for "PHP Version 8"
# Maintainer: Ondřej Súkup <osukup@suse.cz> Fabian Vogt <fvogt@suse.de>

use base "consoletest";
use strict;
use warnings;
use utils;
use testapi;
use apachetest;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    setup_apache2(mode => 'PHP8');
    assert_script_run('curl http://localhost/index.php | tee /tmp/tests-console-php8.txt');
    assert_script_run('grep "PHP Version 8" /tmp/tests-console-php8.txt');

    # test function provided by external module (php8-zlib RPM)
    zypper_call 'in php8-zlib';
    my $code = '
    $dc = deflate_init(ZLIB_ENCODING_GZIP);
    $data = deflate_add($dc, "TEST\n", ZLIB_FINISH);
    $ic = inflate_init(ZLIB_ENCODING_GZIP);
    print(inflate_add($ic, $data, ZLIB_FINISH));';
    # Newlines cause continuation lines and confuse serial matching
    $code =~ s/\n//g;
    assert_script_run("php -r '$code' | grep TEST");

    # test reading file
    assert_script_run('php -r \'echo readfile("/etc/hosts")."\\n";\' | grep localhost');
}
1;
