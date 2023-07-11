# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection)
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ip = $self->get_ip(type => 'host');

    record_info('Info', "Set up static addresses $ip");
    $self->get_from_data('wicked/static_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());

    $self->do_barrier('setup');

    my $cursor = $self->get_log_cursor();
    $cursor = "-c '$cursor'" if (length($cursor) > 0);
    $self->wicked_command('ifup', $ctx->iface());

    die("The IP $ip should not be set") if $self->get_current_ip($ctx->iface()) eq $ip;

    $ip =~ s/\./\\./g;
    my $dup_regex =
      $self->check_wicked_version('>=0.6.73') ?
      "IPv4 duplicate address ipv4 $ip" :
      "IPv4 duplicate address $ip detected";
    validate_script_output("journalctl $cursor -p3 -u wickedd.service", qr/$dup_regex/);

    # Avoid logchecker anouncing an expected error
    my $varname = 'WICKED_CHECK_LOG_EXCLUDE_' . uc($self->{name});
    set_var($varname, get_var($varname, '') . ",wickedd=$dup_regex");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
