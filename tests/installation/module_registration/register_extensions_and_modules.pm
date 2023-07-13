# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register Application module
#          in "Extension and Module Selection" dialog
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi qw(save_screenshot get_required_var);

sub run {
    my @scc_addons = grep($_, split(/,/, get_required_var('SCC_ADDONS')));
    $testapi::distri->get_module_registration()->register_extension_and_modules([@scc_addons]);
    save_screenshot;
    foreach my $addon (@scc_addons) {
        if ($addon =~ /we|ha|ltss/) {
            $testapi::distri->wait_for_separate_regcode({
                    timeout => 60,
                    interval => 2,
                    message => 'Page to insert separate registration code did not appear'});
            my $regcode = get_required_var('SCC_REGCODE_' . uc $addon);
            $testapi::distri->get_module_regcode()->add_separate_registration_code($addon, $regcode);

            save_screenshot;
            $testapi::distri->get_module_regcode()->trust_gnupg_key() if ($addon eq 'we');
        }
    }
}

1;
