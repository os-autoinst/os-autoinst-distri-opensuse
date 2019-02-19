# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 15: Create a macvtap interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use network_utils 'iface';

our $macvtap_log = '/tmp/macvtap_results.txt';

sub run {
    my ($self) = @_;
    record_info('Info', 'Create a macvtap interface from legacy ifcfg files');
    my $config     = '/etc/sysconfig/network/ifcfg-macvtap1';
    my $iface      = iface();
    my $ip_address = $self->get_ip(type => 'macvtap', netmask => 1);
    $ip_address =~ s'/'\\/';
    my $ref_ip = $self->get_ip(type => 'host', netmask => 0, is_wicked_ref => 1);
    $self->get_from_data('wicked/ifcfg/macvtap1',    $config);
    $self->get_from_data('wicked/ifcfg/macvtap_eth', '/etc/sysconfig/network/ifcfg-' . $iface);
    $self->get_from_data('wicked/check_macvtap',     'check_macvtap', executable => 1);
    assert_script_run("sed 's/iface/$iface/' -i $config");
    assert_script_run("sed 's/ip_address/$ip_address/' -i $config");
    $self->wicked_command('ifreload', $iface);
    $self->wicked_command('ifup',     'macvtap1');
    $ip_address = $self->get_ip(type => 'macvtap', netmask => 0);
    my $cmd_text = "./check_macvtap $ref_ip $ip_address > $macvtap_log 2>&1 &";
    type_string($cmd_text);
    wait_serial($cmd_text, undef, 0, no_regex => 1);
    type_string("\n");
    # arping not getting packet back it is expected because check_macvtap
    # executable is consume it from tap device before it actually reaches arping
    script_run("arping -c 1 -I macvtap1 $ref_ip");
    validate_script_output("cat $macvtap_log", sub { m/Success listening to tap device/ });
    upload_logs($macvtap_log);
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    upload_logs($macvtap_log);
    $self->SUPER::post_fail_hook;
}

1;
