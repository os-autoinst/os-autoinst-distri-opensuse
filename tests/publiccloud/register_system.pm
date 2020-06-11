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
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use version_utils;
use registration;
use warnings;
use testapi;
use strict;
use utils;

sub run {
    my ($self, $args) = @_;

    my @addons = split(/,/, get_var('SCC_ADDONS', ''));

    select_console 'tunnel-console';

    $args->{my_instance}->run_ssh_command(cmd => "sudo SUSEConnect -r " . get_required_var('SCC_REGCODE'), timeout => 420) unless (get_var('FLAVOR') =~ 'On-Demand');

    for my $addon (@addons) {
        if (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
            ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon), '`echo ${VERSION} | cut -d- -f1`') unless ($addon eq '');
        } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
            ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon), '${VERSION_ID}') unless ($addon eq '');
        } else {
            ssh_add_suseconnect_product($args->{my_instance}->public_ip, get_addon_fullname($addon)) unless ($addon eq '');
        }
    }

    $args->{my_instance}->run_ssh_command(cmd => "sudo zypper lr");
}

1;

