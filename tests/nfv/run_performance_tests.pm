# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run NFV Performance tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use lockapi;

sub run {
    select_console 'root-ssh';

    record_info("Check Hugepages");
    assert_script_run('cat /proc/meminfo |grep -i huge');
    record_info("Start test");
    assert_script_run('source /root/vsperfenv/bin/activate && cd /root/vswitchperf/');
    assert_script_run('./vsperf --conf-file=/root/vswitchperf/conf/10_custom.conf --vswitch OvsVanilla phy2phy_tput',
        timeout => 3600);
    mutex_create("NFV_TESTING_DONE");

    record_info("Upload logs");
    script_run("cd /tmp");
    script_run(q(find . -type d -name "results*"|xargs -d "\n" tar -czvf vsperf_logs.tar.gz));
    upload_logs('vsperf_logs.tar.gz', failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
