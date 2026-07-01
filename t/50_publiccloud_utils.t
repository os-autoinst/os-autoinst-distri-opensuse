use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::Warnings;
use testapi 'set_var';

# Import publiccloud::utils so the functions under test are called by their
# imported (unqualified) names. This implicitly exercises the module's export
# boundary: exported helpers resolve here without a package prefix, while
# non-exported helpers must still be called fully-qualified.
use publiccloud::utils;

sub _unset { for my $k (@_) { set_var($k, undef) } }

# --- export boundary ----------------------------------------------------------
#
# Calling exported helpers unqualified below only works if they are actually
# exported. Assert the boundary explicitly so an accidental change to @EXPORT
# is caught here rather than as a confusing "Undefined subroutine" failure.
subtest '[export boundary] exported vs internal helpers' => sub {
    for my $exported (qw(
        is_byos is_ondemand is_ec2 is_ec2_xen is_azure is_gce
        is_container_host is_hardened is_cloudinit_supported
        get_python_exec get_ssh_private_key_path pc_data_url
        additional_repos calculate_custodian_ttl
        )) {
        ok(__PACKAGE__->can($exported), "$exported is exported into caller");
    }

    # Internal helpers are intentionally NOT exported; they must be reached via
    # the fully-qualified name only.
    for my $internal (qw(venv_generate_runner_script)) {
        ok(!__PACKAGE__->can($internal), "$internal is not exported");
        ok(publiccloud::utils->can($internal), "$internal exists in the module");
    }
};

# --- provider / flavor predicates ---------------------------------------------

subtest '[is_byos]' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'SLES-15-SP6-BYOS');
    ok is_byos(), 'BYOS detected (upper)';

    set_var('FLAVOR', 'sles-something-byos');
    ok is_byos(), 'BYOS detected (lower, /byos/i)';

    set_var('FLAVOR', 'SLES-15-SP6-On-Demand');
    ok !is_byos(), 'not BYOS when FLAVOR lacks token';

    set_var('PUBLIC_CLOUD', 0);
    ok !is_byos(), 'not BYOS outside public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};

subtest '[is_ondemand]' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'On-Demand-ish');
    ok is_ondemand(), 'on-demand when not BYOS';

    set_var('FLAVOR', 'BYOS');
    ok !is_ondemand(), 'not on-demand when BYOS';

    set_var('PUBLIC_CLOUD', 0);
    ok !is_ondemand(), 'not on-demand outside public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};

subtest '[provider checks]' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok is_ec2(), 'EC2 true';
    ok !is_azure(), 'AZURE false';
    ok !is_gce(), 'GCE false';

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok is_azure(), 'AZURE true';
    ok !is_ec2(), 'EC2 false';
    ok !is_gce(), 'GCE false';

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    ok is_gce(), 'GCE true';
    ok !is_ec2(), 'EC2 false';
    ok !is_azure(), 'AZURE false';

    set_var('PUBLIC_CLOUD', 0);
    ok !is_ec2(), 'EC2 false when not public cloud';
    ok !is_azure(), 'AZURE false when not public cloud';
    ok !is_gce(), 'GCE false when not public cloud';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER/);
};

subtest '[flavor flags] CHOST & Hardened' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'SLE-CHOST-15-SP6');
    ok is_container_host(), 'CHOST detected';

    set_var('FLAVOR', 'SLE-Hardened-15-SP6');
    ok is_hardened(), 'Hardened detected';

    set_var('FLAVOR', 'SLE-Whatever');
    ok !is_container_host(), 'CHOST not detected';
    ok !is_hardened(), 'Hardened not detected';

    set_var('PUBLIC_CLOUD', 0);
    set_var('FLAVOR', 'SLE-CHOST-15-SP6');
    ok !is_container_host(), 'CHOST requires public cloud';
    set_var('FLAVOR', 'SLE-Hardened-15-SP6');
    ok !is_hardened(), 'Hardened requires public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};

subtest '[is_cloudinit_supported]' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('DISTRI', 'sle');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok is_cloudinit_supported(), 'AZURE + sle => supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok is_cloudinit_supported(), 'EC2 + sle => supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    ok !is_cloudinit_supported(), 'GCE + sle => not supported';

    set_var('DISTRI', 'sle-micro');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok !is_cloudinit_supported(), 'AZURE + sle-micro => NOT supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok !is_cloudinit_supported(), 'EC2 + sle-micro => NOT supported';

    set_var('PUBLIC_CLOUD', 0);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok !is_cloudinit_supported(), 'not public cloud => NOT supported';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER DISTRI/);
};

subtest '[is_ec2_xen] instance type matching' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 't2.micro');
    ok is_ec2_xen(), 't2 is Xen-based';
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'm4.large');
    ok is_ec2_xen(), 'm4 is Xen-based';
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'm5.large');
    ok !is_ec2_xen(), 'm5 is Nitro (not Xen)';
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'c6g.large');
    ok !is_ec2_xen(), 'c6g is Nitro (not Xen)';

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 't2.micro');
    ok !is_ec2_xen(), 'not Xen when provider is not EC2';

    # When PUBLIC_CLOUD is not defined the run is not a public cloud run,
    # so the predicate must be false regardless of provider/instance type.
    _unset('PUBLIC_CLOUD');
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    set_var('PUBLIC_CLOUD_INSTANCE_TYPE', 't2.micro');
    ok !is_ec2_xen(), 'not Xen when PUBLIC_CLOUD is undefined';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_INSTANCE_TYPE/);
};

# --- pure helpers -------------------------------------------------------------

subtest '[get_python_exec] default version' => sub {
    like(get_python_exec(), qr{^python\d+\.\d+$}, 'returns pythonXX.YY');
};

subtest '[get_ssh_private_key_path] depends on provider/LTP' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    is(get_ssh_private_key_path(), '~/.ssh/id_rsa', 'azure uses rsa');

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    set_var('PUBLIC_CLOUD_LTP', undef);
    is(get_ssh_private_key_path(), '~/.ssh/id_ed25519', 'ec2 uses ed25519');

    # rsa is only forced for azure/LTP; any other (even unknown) provider
    # falls through to ed25519, so the value here is not EC2-specific.
    set_var('PUBLIC_CLOUD_PROVIDER', 'DONALDUCK');
    is(get_ssh_private_key_path(), '~/.ssh/id_ed25519', 'non-azure provider uses ed25519');

    set_var('PUBLIC_CLOUD_LTP', 1);
    is(get_ssh_private_key_path(), '~/.ssh/id_rsa', 'LTP forces rsa');

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_LTP/);
};

subtest '[pc_data_url] github/gitlab/gitea URL conversion' => sub {
    set_var('TEST_GIT_HASH', 'abc123');

    set_var('TEST_GIT_URL', 'git@github.com:foo/bar.git');
    is(pc_data_url('x/y.sh'),
        'https://github.com/foo/bar/raw/abc123/data/x/y.sh', 'github ssh url converted');

    set_var('TEST_GIT_URL', 'https://gitlab.suse.de/foo/bar.git');
    is(pc_data_url('x/y.sh'),
        'https://gitlab.suse.de/foo/bar/-/raw/abc123/x/y.sh', 'gitlab url converted');

    set_var('TEST_GIT_URL', 'https://src.suse.de/foo/bar');
    is(pc_data_url('x/y.sh'),
        'https://src.suse.de/foo/bar/src/commit/abc123/x/y.sh', 'gitea fallback');

    _unset(qw/TEST_GIT_URL TEST_GIT_HASH/);
};

subtest '[additional_repos] xfs repo composition' => sub {
    set_var('PUBLIC_CLOUD_XFS', undef);
    my @none = additional_repos();
    is(scalar @none, 0, 'no extra repos without PUBLIC_CLOUD_XFS');

    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    # plain is_sle() true, but version-qualified is_sle(">=16.0") false => SLE prefix
    $utils->redefine(is_sle => sub { return @_ ? 0 : 1 });
    $utils->redefine(is_sle_micro => sub { 0 });
    set_var('PUBLIC_CLOUD_XFS', 1);
    set_var('VERSION', '15-SP6');
    my @repos = additional_repos();
    is(scalar @repos, 1, 'one repo added for xfs');
    like($repos[0], qr{QA:/Head/SLE-15-SP6/}, 'repo path uses SLE prefix and version');

    _unset(qw/PUBLIC_CLOUD_XFS VERSION/);
};

subtest '[calculate_custodian_ttl] ISO 8601 with offset' => sub {
    my $res = calculate_custodian_ttl(3600);
    like($res, qr{^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$}, 'ISO 8601 Z format');

    # The difference between two ttls should equal the difference in offsets.
    use Time::Local qw(timegm);
    my $parse = sub {
        my ($Y, $M, $D, $h, $m, $s) = $_[0] =~ m{^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z$};
        return timegm($s, $m, $h, $D, $M - 1, $Y);
    };
    my $t0 = $parse->(calculate_custodian_ttl(0));
    my $t1 = $parse->(calculate_custodian_ttl(7200));
    cmp_ok($t1 - $t0, '>=', 7199, 'ttl offset reflected (lower bound, allows 1s clock tick)');
    cmp_ok($t1 - $t0, '<=', 7201, 'ttl offset reflected (upper bound)');
};

done_testing;
