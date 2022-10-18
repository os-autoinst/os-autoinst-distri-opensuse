# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: php8-mysql mysql sudo
# Summary: PHP8 code that interacts locally with MySQL
#   This tests creates a MySQL database and inserts an element. Then,
#   PHP reads the elements and writes a new one in the database. If
#   all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE
# - Setup apache to use php8 modules
# - Install php8-mysql mysql sud
# - Restart mysql service
# - Create a test database
# - Insert a element "can you read this?"
# - Grab a php test file from datadir, test it with curl in apache
# - Run select manually to check for the element
# - Drop created database
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_leap php_version);
use registration qw(add_suseconnect_product get_addon_fullname);
use apachetest;

sub run {
    my $self = shift;
    select_serial_terminal;

    my ($php, $php_pkg, $php_ver) = php_version();
    setup_apache2(mode => uc($php));
    # install requirements
    zypper_call "in $php-mysql mysql sudo";

    systemctl 'restart mysql', timeout => 300;

    test_mysql;
}
1;
