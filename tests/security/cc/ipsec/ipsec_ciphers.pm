# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run EAL4 'ipsec ciphers' case
#          Make sure that the allowed ESP and IKE algorithms establish a
#          connection with the expected proposal, and that ESP proposals
#          which mix classic and AEAD algorithms are rejected.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110980, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use lockapi;
use security::cc_ipsec;

# The ESP cases use an IKE proposal without '!', thus strongSwan adds its
# default proposals and the IKE_SA is always established. The IKE cases do
# the same for ESP.
my %esp_cases = (
    'aes128-sha512-modp2048!' => qr{ESP:AES_CBC_128/HMAC_SHA2_512_256/},
    'aes192-aes192gmac-modp2048!' => undef,
    'aes192gmac-modp2048!' => qr{ESP:NULL_AES_GMAC_192/},
    'prfsha1-aes256-aes192gmac-modp2048!' => undef,
    'prfsha1-aes256-sha256-modp2048!' => qr{ESP:AES_CBC_256/HMAC_SHA2_256_128/},
);
my %ike_cases = (
    'aes256ctr-sha256-modp2048!' => qr{IKE:AES_CTR_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048},
    'aes128ctr-sha256-modp6144!' => qr{IKE:AES_CTR_128/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_6144},
    'aes128gcm12-sha256-modp2048!' => qr{IKE:AES_GCM_12_128/PRF_HMAC_SHA2_256/MODP_2048},
    'aes256ccm8-sha256-modp3072!' => qr{IKE:AES_CCM_8_256/PRF_HMAC_SHA2_256/MODP_3072},
);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # In FIPS mode the kernel disables rfc4543(gcm(aes)), that is AES-GMAC for
    # ESP. The server selects the proposal, cannot install the SA and answers
    # NO_PROPOSAL_CHOSEN. ipsec_server checks in its journal that this is the
    # reason.
    my $fips = script_output('cat /proc/sys/crypto/fips_enabled', proceed_on_failure => 1) =~ /^\s*1\s*$/;

    my @cases;
    foreach my $esp (sort keys %esp_cases) {
        my $proposal = $esp_cases{$esp};
        my %expect;
        if (!$proposal) {
            # A proposal that mixes classic and AEAD algorithms is invalid
            %expect = (expect => 'invalid');
        }
        elsif ($fips && $esp =~ /gmac/) {
            %expect = (expect => 'fail', reason => qr/received NO_PROPOSAL_CHOSEN notify, no CHILD_SA built/);
        }
        else {
            %expect = (expect => 'pass', proposal => $proposal);
        }
        push @cases, {
            name => "ESP: $esp",
            conf => {keyexchange => 'ikev2', ike => 'aes256ctr-sha256-modp2048', esp => $esp},
            %expect,
        };
    }
    foreach my $ike (sort keys %ike_cases) {
        push @cases, {
            name => "IKE: $ike",
            conf => {keyexchange => 'ikev2', ike => $ike, esp => 'aes128-sha512-modp2048'},
            expect => 'pass',
            proposal => $ike_cases{$ike},
        };
    }

    foreach my $case (@cases) {
        $self->result('fail') unless run_ipsec_case(%$case);
    }

    mutex_create('IPSEC_CLIENT_DONE');
    $self->{client_done} = 1;
}

sub test_flags {
    # The next client modules need the tunnel and the IPsec configuration
    # of this module, thus do not roll back to the last milestone on failure
    return {no_rollback => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    # The server waits for this mutex, do not leave it waiting until the job times out
    eval { mutex_create('IPSEC_CLIENT_DONE') } unless $self->{client_done};
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
