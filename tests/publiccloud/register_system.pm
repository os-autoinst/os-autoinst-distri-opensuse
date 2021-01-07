# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register the remote system
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use version_utils;
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils qw(select_host_console is_ondemand);

sub run {
    my ($self, $args) = @_;

    if (is_ondemand) {
        # on OnDemand image we use `registercloudguest` to register and configure the repositories
        $args->{my_instance}->retry_ssh_command("sudo registercloudguest", timeout => 420, retry => 3);
    } else {
        my @addons = split(/,/, get_var('SCC_ADDONS', ''));

        select_host_console();    # select console on the host, not the PC instance

        # note: ssh_script_retry dies on failure
        $args->{my_instance}->retry_ssh_command("sudo SUSEConnect -r " . get_required_var('SCC_REGCODE'), timeout => 420, retry => 3);
        my $arch = get_var('PUBLIC_CLOUD_ARCH') // "x86_64";
        $arch = "aarch64" if ($arch eq "arm64");
        for my $addon (@addons) {
            next if ($addon =~ /^\s+$/);
            if (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
                ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon), '`echo ${VERSION} | cut -d- -f1`', $arch);
            } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
                ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon), '${VERSION_ID}', $arch);
            } else {
                ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon), undef, $arch);
            }
        }
    }
    record_info('LR', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper lr || true"));
    record_info('LS', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper ls || true"));
}

1;

