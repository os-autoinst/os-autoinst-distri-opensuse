# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mkdud
# Summary: Generate DUD dynamically using mkdud and xml file where variables
# are expanded for the corresponding product/build.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use XML::Writer;
use utils qw(zypper_call);
use autoyast qw(expand_variables generate_xml);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_console 'root-console';

    my $xml = 'add_on_products.xml';
    my $dud = get_required_var('DUD');

    my $repos = get_var('MAINT_TEST_REPO', '');
    my $content = ($repos eq '') ? expand_variables(get_test_data($xml)) : generate_xml($repos);
    save_tmp_file($xml, $content);
    add_suseconnect_product(get_addon_fullname('phub'));
    zypper_call('in mkdud');
    assert_script_run('wget -P inst-sys ' . autoinst_url . "/files/$xml");
    assert_script_run("mkdud --create $dud --dist sle15 " .
          "--install instsys,repo --obs-keys --name 'Update' inst-sys");
    upload_asset($dud);
    upload_logs("inst-sys/$xml");
}

1;
