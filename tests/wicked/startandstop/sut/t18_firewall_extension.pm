# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Verify firewalld zone settings after ifup/ifdown/ifreload
# Maintainer:
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use Utils::Systemd;
use version_utils 'is_sle';

has wicked_version => '>=0.6.70';

sub run {
    my ($self, $ctx) = @_;
    my $ifc = $ctx->iface();

    return if ($self->skip_by_wicked_version());

    # No firewalld on sles 12-SP5 (bsc#1180116)
    if (is_sle('<=12-SP5')) {
        $self->result('skip');
        return;
    }

    systemctl('enable --now firewalld');

    $self->get_from_data('wicked/test-ext-firewall.sh', '/tmp/test-ext-firewall.sh', executable => 1);
    $self->run_test_shell_script("ext-firewall $ifc", "time /tmp/test-ext-firewall.sh '$ifc'");

    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
