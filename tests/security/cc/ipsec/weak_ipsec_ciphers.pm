# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run EAL4 'Weak IPsec ciphers' case
#          Make sure that weak IPsec configurations do not establish
#          a connection. The server accepts the IKE proposal, thus the
#          weak ESP proposal is rejected when the CHILD_SA is negotiated.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101226, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use security::cc_ipsec;

my @cases = (
    {
        name => 'IKEv1',
        conf => {keyexchange => 'ikev1', ike => 'aes256ctr-sha256-modp2048!', esp => 'aes128-sha512-modp2048'},
        expect => 'fail',
        reason => qr/received NO_PROPOSAL_CHOSEN error notify/,
    },
    {
        name => 'ESP: 3des-sha256-ecp224bp!',
        conf => {keyexchange => 'ikev2', ike => 'aes256ctr-sha256-modp2048!', esp => '3des-sha256-ecp224bp!'},
        expect => 'fail',
        reason => qr/received NO_PROPOSAL_CHOSEN notify, no CHILD_SA built/,
    },
);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    foreach my $case (@cases) {
        $self->result('fail') unless run_ipsec_case(%$case);
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
