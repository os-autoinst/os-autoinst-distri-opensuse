# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SUSE or openSUSE WSL images from the MS Store directly
# Maintainer: qa-perf  <qa-perf@suse.de>

use base 'y2_installbase';

use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $alp_ip;
    my $alp_mac;
    my $output;

    # Login into ALP
    assert_screen("alp-login");
    type_string("root");
    send_key("ret");
    type_password("opensuse");
    send_key("ret");
    wait_still_screen('5');
    assert_and_dclick("alp-login");
    assert_and_click("virt-viewer-gui");
    save_screenshot;
    assert_screen("virt-viewer-gui-confirmation-message");
    send_key('alt-o');
    wait_still_screen('5');

    # Get VM's IP
    script_output("virsh domiflist ALP_m | grep br0") =~ m/((\w{2}\:){5}\w{2})/;
    $alp_ip = script_output("ip neigh | grep $1");
    record_info("ALP IP", "ALP VM IP: $alp_ip");

    # Run SLEperf script
    assert_script_run("wget -O /tmp/sleperf_alp.sh " . data_url("alp_performance/sleperf_alp.sh"));
    assert_script_run("chmod +x /tmp/sleperf_alp.sh && /tmp/sleperf_alp.sh");
}

1;
