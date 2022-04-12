# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: php? php?-zlib
# Summary: Simple PHP? code hosted locally
#   This test requires the Web and Scripting module on SLE.
# - Setup apache2 to use php? modules
# - Run "curl http://localhost/index.php", check output for "PHP Version ?"
# Maintainer: QE Core <qe-core@suse.com>
use base "consoletest";
use strict;
use warnings;
use utils;
use testapi;
use apachetest;
use version_utils qw(is_leap is_sle);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    
    if (is_sle) {
        my $vers = substr(get_var("VERSION"),0,2);
        my $arch = get_var("ARCH");
        assert_script_run("SUSEConnect -p sle-module-web-scripting/$vers/$arch");
    }

    my $php_vers = '';
    if (is_leap('<15.0') || is_sle('<15')) {
        $php_vers = '5';
    }
    elsif (is_leap("<15.4") || is_sle("<15-SP4")) {
        $php_vers = '7';
    }
    else {
        $php_vers = '8';
    }

    setup_apache2(mode => uc('php'.$php_vers));
    assert_script_run('curl http://localhost/index.php | tee /tmp/tests-console-php'.$php_vers.'.txt');
    assert_script_run('grep "PHP Version '.$php_vers.'" /tmp/tests-console-php'.$php_vers.'.txt');

    if (($php_vers eq '5') || ($php_vers eq '7')) {
        zypper_call 'in php'.$php_vers.'-json';
        assert_script_run('php -r \'echo json_encode(array("foo" => true))."\\n";\' | grep :true');
    }
    else {
        zypper_call 'in php8-zlib';
        my $code = '
        $dc = deflate_init(ZLIB_ENCODING_GZIP);
        $data = deflate_add($dc, "TEST\n", ZLIB_FINISH);
        $ic = inflate_init(ZLIB_ENCODING_GZIP);
        print(inflate_add($ic, $data, ZLIB_FINISH));';
        # Newlines cause continuation lines and confuse serial matching
        $code =~ s/\n//g;
        assert_script_run("php -r '$code' | grep TEST");
    }

    # test reading file
    assert_script_run('php -r \'echo readfile("/etc/hosts")."\\n";\' | grep localhost');
}
1;
