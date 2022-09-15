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
use version_utils qw(is_leap is_sle php_version);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('script'), (is_sle('<15') ? '12' : undef)) if (is_sle('<15-sp4'));

    my ($php, $php_pkg, $php_ver) = php_version();

    setup_apache2(mode => uc('php' . $php_ver));
    assert_script_run('curl http://localhost/index.php | tee /tmp/tests-console-php' . $php_ver . '.txt');
    assert_script_run('grep "PHP Version ' . $php_ver . '" /tmp/tests-console-php' . $php_ver . '.txt');

    if (($php_ver eq '5') || ($php_ver eq '7')) {
        zypper_call 'in php' . $php_ver . '-json';
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
