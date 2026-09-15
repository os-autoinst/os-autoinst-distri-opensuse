use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::MockObject;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

# Import publiccloud::utils so the functions under test are called by their
# imported (unqualified) names. This implicitly exercises the module's export
# boundary: exported helpers resolve here without a package prefix, while
# non-exported helpers must still be called fully-qualified.
use publiccloud::utils;

sub _unset { for my $k (@_) { set_var($k, undef) } }

my $T = publiccloud::utils::ZYPP_LOCK_TIMEOUT;

subtest '[ZYPP_LOCK_TIMEOUT] stays below the client-side ssh timeout it runs under' => sub {
    # The wrapped command also runs under a client-side timeout. If libzypp
    # waits longer than that, the worker gives up first -- and since
    # ssh_script_output()/ssh_script_retry() do not wrap the remote side in
    # `timeout`, the remote command keeps running and keeps holding the lock,
    # so the next retry collides with our own orphan (poo#206763).
    cmp_ok($T, '<', $bmwqemu::default_timeout, "inner lock wait ${T}s is below the smallest client-side default ($bmwqemu::default_timeout" . 's)');
};

subtest '[with_zypp_lock_timeout] sudo commands get the env indirection' => sub {
    is(with_zypp_lock_timeout('sudo zypper -n ref'), "sudo env ZYPP_LOCK_TIMEOUT=$T zypper -n ref", 'inserted right after sudo');
    is(with_zypp_lock_timeout('sudo  SUSEConnect -s'), "sudo  env ZYPP_LOCK_TIMEOUT=$T SUSEConnect -s", 'tolerates extra whitespace after sudo, preserving it');
};

subtest '[with_zypp_lock_timeout] non-sudo commands get a plain prefix' => sub {
    is(with_zypp_lock_timeout('zypper -n lr'), "ZYPP_LOCK_TIMEOUT=$T zypper -n lr", 'plain prefix, no env indirection needed');
    is(with_zypp_lock_timeout('pgrep -a zypper'), "ZYPP_LOCK_TIMEOUT=$T pgrep -a zypper", 'harmless no-op prefix for non-libzypp commands too');
};

subtest '[with_zypp_lock_timeout] sudo commands with their own flag are left untouched' => sub {
    # inserting env between "sudo" and its own flag would corrupt these --
    # the flag would land on env, not sudo (real call sites: wait_for_sudo's
    # "sudo -n true", instance.pm's "sudo -s command -v supportconfig")
    is(with_zypp_lock_timeout('sudo -n true'), "ZYPP_LOCK_TIMEOUT=$T sudo -n true", 'sudo -n left untouched, falls back to plain prefix');
    is(with_zypp_lock_timeout('sudo -s command -v supportconfig'), "ZYPP_LOCK_TIMEOUT=$T sudo -s command -v supportconfig", 'sudo -s left untouched too');
};

subtest '[with_zypp_lock_timeout] leading ! (pipeline negation) is preserved, not corrupted' => sub {
    # a plain VAR=val prefix in front of "!" makes the shell try to run "!"
    # itself as a command (bash: !: command not found, exit 127) -- this
    # broke pc_wait_quit's own lock-busy check in every single publiccloud
    # job before being fixed (poo#206763)
    is(with_zypp_lock_timeout('! pgrep -a "zypper|packagekit"'), "! ZYPP_LOCK_TIMEOUT=$T pgrep -a \"zypper|packagekit\"", 'pgrep check stays a valid negated pipeline');
    is(with_zypp_lock_timeout('! systemctl is-active google-startup-scripts.service'), "! ZYPP_LOCK_TIMEOUT=$T systemctl is-active google-startup-scripts.service", 'systemctl check stays valid too');
    is(with_zypp_lock_timeout('! sudo SUSEConnect -d'), "! sudo env ZYPP_LOCK_TIMEOUT=$T SUSEConnect -d", 'a negated sudo command gets both fixes applied');
    is(with_zypp_lock_timeout('  ! pgrep -a zypper'), "! ZYPP_LOCK_TIMEOUT=$T pgrep -a zypper", 'leading whitespace does not sneak past the ! guard');
};

subtest '[with_zypp_lock_timeout] every sudo occurrence in a chained/piped command is wrapped' => sub {
    is(
        with_zypp_lock_timeout('sudo mkdir /tmp/x;sudo chmod 777 /tmp/x'),
        "sudo env ZYPP_LOCK_TIMEOUT=$T mkdir /tmp/x;sudo env ZYPP_LOCK_TIMEOUT=$T chmod 777 /tmp/x",
        'both sides of a ; chain get wrapped, not just the first'
    );
    is(
        with_zypp_lock_timeout("echo hi | xargs -r sudo zypper -n ref"),
        "echo hi | xargs -r sudo env ZYPP_LOCK_TIMEOUT=$T zypper -n ref",
        'sudo appearing after a pipe (not at the start of the string) still gets wrapped'
    );
    is(
        with_zypp_lock_timeout('sudo -n true && sudo zypper -n ref'),
        "sudo -n true && sudo env ZYPP_LOCK_TIMEOUT=$T zypper -n ref",
        'a flag-guarded sudo and a real one in the same chain are handled independently'
    );
};

# --- export boundary ----------------------------------------------------------
#
# Calling exported helpers unqualified below only works if they are actually
# exported. Assert the boundary explicitly so an accidental change to @EXPORT
# is caught here rather than as a confusing "Undefined subroutine" failure.
subtest '[export boundary] exported vs internal helpers' => sub {
    for my $exported (qw(
        is_byos is_ondemand is_ec2 is_ec2_xen is_azure is_gce
        is_container_host is_hardened is_cloudinit_supported
        get_python_exec get_ssh_key_algo get_ssh_private_key_path pc_data_url
        additional_repos calculate_custodian_ttl with_zypp_lock_timeout
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

subtest '[get_ssh_key_algo] PUBLIC_CLOUD_SSH_KEY_ALGO overrides the default' => sub {
    set_var('PUBLIC_CLOUD', 1);

    # Unset and empty behave alike: fall back to the provider/LTP default.
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    set_var('PUBLIC_CLOUD_SSH_KEY_ALGO', undef);
    is(get_ssh_key_algo(), 'ed25519', 'unset falls back to the default');
    set_var('PUBLIC_CLOUD_SSH_KEY_ALGO', '');
    is(get_ssh_key_algo(), 'ed25519', 'empty string falls back to the default');

    # The override wins over the ed25519 default ...
    set_var('PUBLIC_CLOUD_SSH_KEY_ALGO', 'rsa');
    is(get_ssh_key_algo(), 'rsa', 'rsa override on a ed25519-by-default provider');
    is(get_ssh_private_key_path(), '~/.ssh/id_rsa', 'key path follows the override');

    # ... over the azure rsa default ...
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_SSH_KEY_ALGO', 'ed25519');
    is(get_ssh_key_algo(), 'ed25519', 'ed25519 override beats the azure rsa default');
    is(get_ssh_private_key_path(), '~/.ssh/id_ed25519', 'key path follows the override');

    # ... and over the LTP rsa default.
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    set_var('PUBLIC_CLOUD_LTP', 1);
    is(get_ssh_key_algo(), 'ed25519', 'ed25519 override beats the LTP rsa default');
    _unset(qw/PUBLIC_CLOUD_LTP/);

    # Anything else is a hard error: a silently wrong algorithm would only
    # surface much later as an unexplained ssh timeout. The match is
    # case-sensitive on purpose, so the setting has exactly one spelling.
    for my $bogus (qw(dsa ecdsa id_rsa 1 ED25519 RSA Rsa)) {
        set_var('PUBLIC_CLOUD_SSH_KEY_ALGO', $bogus);
        throws_ok { get_ssh_key_algo() } qr/Unsupported PUBLIC_CLOUD_SSH_KEY_ALGO/, "'$bogus' is rejected";
    }

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER PUBLIC_CLOUD_LTP PUBLIC_CLOUD_SSH_KEY_ALGO/);
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

subtest '[register_addons_in_pc] discriminates the no-enabled-repos cause' => sub {
    # poo#205965
    my $zypper = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    $utils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    set_var('SCC_ADDONS', '');

    my $output;
    my $mock_instance = sub {
        my $inst = Test::MockObject->new;
        $inst->mock(username => sub { 'susetest' });
        $inst->mock(public_ip => sub { '1.2.3.4' });
        $inst->mock(ssh_script_output => sub {
                my (undef, %args) = @_;
                return $args{cmd} =~ /SUSEConnect/ ? ($output // '') : '';
        });
        return $inst;
    };

    $zypper->redefine(pc_refresh => sub { return publiccloud::zypper::EXIT_OK });
    lives_ok { register_addons_in_pc($mock_instance->()) } 'EXIT_OK does not die';

    $zypper->redefine(pc_refresh => sub { return publiccloud::zypper::EXIT_NO_REPOS });
    $output = "SLES15-SP6-x86_64 is not managed by SUSEConnect (Not Registered)\n";
    throws_ok {
        register_addons_in_pc($mock_instance->());
    }
    qr/not registered/, 'unregistered system is named as the cause';
    unlike($@, qr/bsc#1245651/, 'the unregistered case does not claim to be bsc#1245651');

    $output = "SUSE Linux Enterprise Server 15 SP6 x86_64 (Activated)\n";
    throws_ok {
        register_addons_in_pc($mock_instance->());
    }
    qr/registered system \(bsc#1245651\)/, 'registered system is named as the cause';

    _unset(qw/SCC_ADDONS/);
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
