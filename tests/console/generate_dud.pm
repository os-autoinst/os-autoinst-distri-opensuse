# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: mkdud
# Summary: Generate DUD dynamically using mkdud and xml file where variables
# are expanded for the corresponding product/build.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils qw(zypper_call);
use autoyast qw(expand_variables);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_console 'root-console';

    my $xml = 'add_on_products.xml';
    my $dud = get_required_var('DUD');

    my $content = expand_variables(get_test_data($xml));
    save_tmp_file($xml, $content);
    add_suseconnect_product(get_addon_fullname('phub'));
    zypper_call('in mkdud');
    assert_script_run('wget -P inst-sys ' . autoinst_url . "/files/$xml");
    assert_script_run("mkdud --create $dud --dist sle15 " .
          "--install instsys,repo --obs-keys --name 'Update' inst-sys");
    upload_asset($dud);
}

1;
