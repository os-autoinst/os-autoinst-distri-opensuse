# SUSE's openQA tests
#
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: da_perf: Diamond Assurance performance test
# Maintainer: jtang@suse.com
package da_perf;
use testapi;
use base "consoletest";
sub run {
    my $self = shift;
    my $wait_switch;
    # Read VAR
    my $product_name = get_var('VERSION');
    my $build = get_var('BUILD');
    my $hosts_ip = get_var('DA_SUT_IP');
    my $hosts_name = get_var('DA_HOSTNAME');
    my $hypervisor = get_var('DA_XEN_HYPERVISOR');
    # Build cmd
    $wait_switch = "-w" if (get_var('WAIT_FINISH'));
    my $cmd = "~/da_perf/deploy.sh -h $hosts_ip -p $product_name -b $build -n $hosts_name -x $hypervisor $wait_switch";
    record_info("Info", $cmd, result => 'ok');
    my $output_log = "~/da_perf/logs/svirt_output_${product_name}_${build}_${hosts_name}_${hosts_ip}_log";
    my $svirt = select_console('svirt', await_console => 0);
    my $ret = $svirt->run_cmd("$cmd |tee $output_log");
    record_info("Info", "Deploy sleperf finished, test will keep RUNNING if not set WAIT_FINISH tag. please visit http://sleperf.da.suse.cz/dashboard-service/ check detail. Machine running progress is under Message Queue tab", result => 'ok');
}
sub post_fail_hook {
    my ($self) = @_;
}
1;
