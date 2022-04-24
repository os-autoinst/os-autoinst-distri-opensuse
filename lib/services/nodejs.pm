# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for nodejs update tests
#
# Maintainer: Lemon Li <leli@suse.com>

package services::nodejs;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

my $service_type = 'Systemd';

# check nodejs package installed as expected
sub check_installed {
    assert_script_run('grep -E "Installing: nodejs16" /tmp/install_nodejs.log');
    script_run('zypper se -i nodejs | tee /tmp/search_nodejs', timeout => 60);
    my $ret_s1 = script_output(q(grep package /tmp/search_nodejs | grep nodejs16 | awk -F\| '{print $1}'));
    my $ret_s2 = script_output(q(grep package /tmp/search_nodejs | grep nodejs-common| awk -F\| '{print $1}'));
    die "Expected package is not installed. ret_s1=$ret_s1' and ret_s2=$ret_s2'" if ('i' ne "$ret_s1" || 'i+' ne "$ret_s2");
}

# remove the nodejs and related log after test
sub clean_nodejs {
    zypper_call("rm nodejs-common");
    assert_script_run('rm /tmp/install_nodejs.log');
    assert_script_run('rm /tmp/search_nodejs');
}

# SLE-21783: Update nodejs-common for SLE15 SP4
# check the nodejs16 is releaseed to SLE15 SP3 & SLE15 SP4
# check the nodejs-common points to nodejs16
# test steps:
# 1) install nodejs-common on SLES15SP3 and migrated SLES15SP4 when wsm is available in SCC_ADDONS
# 2) check nodejs16 is installed together with nodejs-common
sub check_nodejs_common {
    record_info('SLE-21783', 'check nodejs-common');
    # first we check if it's been installed, if so remove it
    zypper_call('rm nodejs-common') if (script_run('rpm -q nodejs-common') == 0);
    zypper_call('in nodejs-common | tee /tmp/install_nodejs.log');
    # check the new installed nodejs
    check_installed;
}

# check nodejs before and after migration
# stage is 'before' or 'after' system migration.
sub full_nodejs_check {
    my (%hash) = @_;
    my ($stage, $type) = ($hash{stage}, $hash{service_type});
    $service_type = $type;
    if ($stage eq 'before') {
        check_nodejs_common();
    }
    else {
        # check the nodejs installed on base system after migration
        check_installed();
        check_nodejs_common();
        clean_nodejs();
    }
}

1;
