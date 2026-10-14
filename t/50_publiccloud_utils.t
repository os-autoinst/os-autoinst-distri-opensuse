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
        additional_repos calculate_custodian_ttl check_dns
        has_gcemetadata_ipv6_stall_bug is_gce_metadata_ipv6_unreachable
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

subtest '[check_dns] resolv.conf and a host, retries and optional failure' => sub {
    # poo#207630
    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    my @infos;
    $utils->redefine(record_info => sub { push @infos, [@_] });
    my (%rc, @cmds);
    my $inst = Test::MockObject->new;
    my (%retries, %delays);
    $inst->mock(ssh_script_retry => sub {
            my (undef, %args) = @_;
            push @cmds, $args{cmd};
            my $check = $args{cmd} =~ /resolv/ ? 'resolv' : 'getent';
            $retries{$check} = $args{retry};
            $delays{$check} = $args{delay};
            return $rc{$check} // 0;
    });
    $inst->mock(ssh_script_output => sub { my (undef, %args) = @_; push @cmds, $args{cmd}; 'DIAG' });
    my $reset = sub { %rc = @_; @cmds = (); @infos = (); %retries = (); %delays = () };
    # The host check_dns resolves: the setting, or scc.suse.com by default.
    my $host;
    my $expect_host = sub { $host = testapi::get_var('PUBLIC_CLOUD_DNS_CHECK_HOST', 'scc.suse.com') };

    _unset(qw/PUBLIC_CLOUD_DNS_CHECK_HOST/);
    $expect_host->();
    $reset->();
    lives_ok { check_dns($inst) } 'a valid resolv.conf and a resolving default host pass';
    like($cmds[0], qr{/etc/resolv\.conf.*nameserver}, 'resolv.conf is checked for a nameserver');
    is_deeply(\%retries, {resolv => 6, getent => 6}, 'both checks use the default retries');
    is_deeply(\%delays, {resolv => 10, getent => 10}, 'both checks use the default delay');
    ok(grep(/getent ahosts \Q$host\E/, @cmds), 'scc.suse.com is resolved by default');

    $reset->();
    lives_ok { check_dns($inst, retry => 12, delay => 2) } 'custom retry settings are accepted';
    is_deeply(\%retries, {resolv => 12, getent => 12}, 'custom retries apply to both checks');
    is_deeply(\%delays, {resolv => 2, getent => 2}, 'custom delay applies to both checks');

    set_var('PUBLIC_CLOUD_DNS_CHECK_HOST', 'smt.example.org');
    $expect_host->();
    $reset->();
    check_dns($inst);
    ok(grep(/getent ahosts \Q$host\E/, @cmds), 'PUBLIC_CLOUD_DNS_CHECK_HOST overrides the host');

    $reset->(resolv => 1);
    throws_ok { check_dns($inst) } qr{/etc/resolv\.conf}, 'an invalid resolv.conf dies';
    is($infos[0][1], 'DIAG', 'diagnostics are recorded before dying');

    $reset->();
    lives_ok { check_dns($inst) } 'a resolving host passes';
    ok(grep(/getent ahosts \Q$host\E/, @cmds), 'the host is resolved with getent');

    $reset->(getent => 2);
    throws_ok { check_dns($inst) } qr/\Q$host\E did not resolve/, 'a host that never resolves dies';
    ok(grep(/getent ahosts \Q$host\E/, @cmds[1 .. $#cmds]), 'diagnostics include the failed lookup');

    $reset->(resolv => 1);
    lives_ok { check_dns($inst, die => 0) } 'an invalid resolv.conf is non-fatal with die => 0';
    is($infos[0][1], 'DIAG', 'non-fatal resolver failure still records diagnostics');
    like($infos[-1][1], qr{/etc/resolv\.conf}, 'non-fatal resolver failure records its reason');

    $reset->(getent => 2);
    lives_ok { check_dns($inst, die => 0) } 'an unresolved host is non-fatal with die => 0';
    is($infos[0][1], 'DIAG', 'non-fatal lookup failure still records diagnostics');
    like($infos[-1][1], qr/\Q$host\E did not resolve/, 'non-fatal lookup failure records its reason');

    set_var('PUBLIC_CLOUD_DNS_CHECK_HOST', 'x; rm -rf /');
    $reset->();
    throws_ok { check_dns($inst) } qr/not a host name/, 'a setting that is not a host name is refused';
    throws_ok { check_dns($inst, die => 0) } qr/not a host name/, 'die => 0 does not bypass host validation';
    ok(!@cmds, 'nothing runs on the instance for a bad setting');

    _unset(qw/PUBLIC_CLOUD_DNS_CHECK_HOST/);
};

subtest '[has_gcemetadata_ipv6_stall_bug] GCE and python-gcemetadata < 1.1.2' => sub {
    # bsc#1277388
    my $version;
    my @cmds;
    my $inst = Test::MockObject->new;
    $inst->mock(ssh_script_output => sub { my (undef, %args) = @_; push @cmds, $args{cmd}; $version });

    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok(!has_gcemetadata_ipv6_stall_bug($inst), 'not affected outside GCE');
    ok(!@cmds, 'nothing runs on the instance outside GCE');

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    $version = "1.1.1\n";
    ok(has_gcemetadata_ipv6_stall_bug($inst), '1.1.1 is affected');
    like($cmds[0], qr/rpm -q .*python-gcemetadata/, 'the version comes from rpm');
    $version = '1.1.2';
    ok(!has_gcemetadata_ipv6_stall_bug($inst), '1.1.2 is not affected');
    $version = '1.2.0';
    ok(!has_gcemetadata_ipv6_stall_bug($inst), '1.2.0 is not affected');
    $version = 'package python-gcemetadata is not installed';
    ok(!has_gcemetadata_ipv6_stall_bug($inst), 'a missing package is not affected');

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER/);
};

subtest '[is_gce_metadata_ipv6_unreachable] IPv4 and IPv6 metadata requests' => sub {
    # bsc#1277388
    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    $utils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my (%rc, @cmds);
    my $inst = Test::MockObject->new;
    $inst->mock(ssh_script_run => sub {
            my (undef, %args) = @_;
            push @cmds, $args{cmd};
            return $rc{$args{cmd} =~ /-6$/ ? 6 : 4};
    });

    %rc = (4 => 0, 6 => 28);
    ok(is_gce_metadata_ipv6_unreachable($inst), 'only IPv4 replies');
    ok((grep { /curl .*-m 5 .*Metadata-Flavor: Google.*metadata\.google\.internal.* -4$/ } @cmds), 'IPv4 request has a time limit');
    ok((grep { /curl .*-m 5 .*Metadata-Flavor: Google.*metadata\.google\.internal.* -6$/ } @cmds), 'IPv6 request has a time limit');

    %rc = (4 => 0, 6 => 0);
    ok(!is_gce_metadata_ipv6_unreachable($inst), 'both reply');
    %rc = (4 => 28, 6 => 28);
    ok(!is_gce_metadata_ipv6_unreachable($inst), 'none replies');
    %rc = (4 => 127, 6 => 127);
    is(is_gce_metadata_ipv6_unreachable($inst), undef, 'undef without curl');
    %rc = (4 => undef, 6 => 28);
    ok(!is_gce_metadata_ipv6_unreachable($inst), 'an IPv4 request without exit code is not a reply');
};

subtest '[registercloudguest] timeout recovery and bsc#1277388' => sub {
    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    my (@soft, @calls, @retry_args, @first_rc);
    my ($version, %curl_rc);
    $utils->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $utils->redefine(record_soft_failure => sub { push @soft, $_[0] });
    $utils->redefine(script_run => sub { 1 });
    my $inst = Test::MockObject->new;
    $inst->mock(username => sub { 'susetest' });
    $inst->mock(public_ip => sub { '1.2.3.4' });
    $inst->mock(ssh_script_retry => sub {
            my (undef, %args) = @_;
            push @calls, $args{cmd};
            push @retry_args, {%args};
            return @first_rc ? shift @first_rc : 0;
    });
    $inst->mock(ssh_script_output => sub {
            my (undef, %args) = @_;
            return $args{cmd} =~ /python-gcemetadata/ ? $version : '11.0.3';
    });
    $inst->mock(ssh_script_run => sub {
            my (undef, %args) = @_;
            push @calls, $args{cmd};
            return $curl_rc{$args{cmd} =~ /-6$/ ? 6 : 4} if $args{cmd} =~ /curl/;
            return 0;
    });
    $inst->mock(ssh_assert_script_run => sub { my (undef, $cmd) = @_; push @calls, $cmd });
    my $reset = sub { @soft = (); @calls = (); @retry_args = (); @first_rc = @_ };

    set_var('SCC_REGCODE', 'ABCD');
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    ($version, %curl_rc) = ('1.1.1', 4 => 0, 6 => 28);

    $reset->(0);
    registercloudguest($inst);
    is(scalar @retry_args, 1, 'a successful first attempt is not retried');
    is($retry_args[0]{retry}, 1, 'the first attempt runs alone');
    is($retry_args[0]{die}, 0, 'the first attempt does not die');
    like($calls[0], qr/sudo registercloudguest\s+-r ABCD/, 'registercloudguest registers with the regcode');
    ok(!(grep { /pkill/ } @calls), 'no process is stopped after a success');

    $reset->(1);
    registercloudguest($inst);
    is($retry_args[-1]{retry}, 2, 'a failure is retried two more times');
    ok(!(grep { /pkill/ } @calls), 'no process is stopped when there is no timeout');
    ok(!@soft, 'no soft failure when there is no timeout');

    $reset->(124);
    registercloudguest($inst);
    ok((grep { /pkill -f '\[r\]egistercloudguest'/ } @calls), 'the old registercloudguest is stopped for bsc#1277388');
    is_deeply(\@soft, ['bsc#1277388 - registercloudguest timeout, gcemetadata stops on the IPv6 metadata server'], 'bsc#1277388 is reported');
    ok((grep { /pkill -f '\[g\]cemetadata'/ } @calls), 'the old gcemetadata is stopped');
    my ($sed) = grep { /sed -i .*\/etc\/hosts/ } @calls;
    ok($sed, '/etc/hosts is changed');
    # Apply the sed expression to an /etc/hosts sample, to check which lines it changes
    my ($expr) = $sed =~ m{sed -i '/(.+?)/s/\^/#/'};
    $expr =~ s/\[\^#\[:space:\]\]/[^#\\s]/g;
    $expr =~ s/\[\^\[:space:\]\]/\\S/g;
    $expr =~ s/\[\[:space:\]\]/\\s/g;
    my @changed = grep { /$expr/ } (
        '127.0.0.1       localhost',
        '::1             localhost ipv6-localhost ipv6-loopback',
        '# 169.254.169.254 metadata.google.internal',
        '169.254.169.254 metadata.google.internal',
        'fd20:ce::254    metadata.google.internal',
        'fd00:aaaa::1 metadata.google.internal metadata',
    );
    is_deeply(\@changed, ['fd20:ce::254    metadata.google.internal', 'fd00:aaaa::1 metadata.google.internal metadata'], 'only the IPv6 addresses of the metadata server are removed');
    is($calls[-1], $calls[0], 'registration runs again after the work-around');
    is($retry_args[-1]{retry}, 2, 'the timeout is retried two more times');

    %curl_rc = (4 => 127, 6 => 127);
    $reset->(124);
    registercloudguest($inst);
    is(scalar @soft, 1, 'without curl, the timeout and the version are sufficient');

    %curl_rc = (4 => 0, 6 => 0);
    $reset->(124);
    registercloudguest($inst);
    ok(!@soft, 'no bsc#1277388 when the IPv6 metadata server replies');
    ok(!(grep { /pkill|etc\/hosts/ } @calls), 'nothing changes on the SUT when the IPv6 metadata server replies');

    ($version, %curl_rc) = ('1.1.2', 4 => 0, 6 => 28);
    $reset->(124);
    registercloudguest($inst);
    ok(!@soft, 'no bsc#1277388 with python-gcemetadata 1.1.2');
    ok(!(grep { /curl/ } @calls), 'no metadata request with python-gcemetadata 1.1.2');
    ok(!(grep { /pkill|etc\/hosts/ } @calls), 'nothing changes on the SUT with python-gcemetadata 1.1.2');

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    $reset->(124);
    registercloudguest($inst);
    ok(!@soft, 'no bsc#1277388 outside GCE');
    ok(!(grep { /pkill|etc\/hosts/ } @calls), 'nothing changes on the SUT outside GCE');

    _unset(qw/SCC_REGCODE PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER/);
};

subtest '[ssh_allow_openqa_port_selinux] addresses $instance directly, not the current console' => sub {
    # poo#207027/#206808: must not depend on any interactive console, so it can run before
    # the interactive ssh tunnel exists and any reboot it triggers takes softreboot()'s
    # simple untunneled path instead of the fragile tunneled leave/reconnect dance.
    my $zypper = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    my @zypper_calls;
    $zypper->redefine(pc_pkg_call => sub {
            my (undef, $cmd) = @_;
            push @zypper_calls, $cmd;
            return 0;
    });
    my $utils = Test::MockModule->new('publiccloud::utils', no_auto => 1);
    $utils->redefine(is_transactional => sub { 1 });
    set_var('QEMUPORT', 20222);

    my @instance_calls;
    my $inst = Test::MockObject->new;
    $inst->mock(ssh_assert_script_run => sub { my (undef, $cmd) = @_; push @instance_calls, $cmd; return 0; });
    $inst->mock(softreboot => sub { push @instance_calls, 'softreboot' });

    ssh_allow_openqa_port_selinux($inst);

    is(scalar @zypper_calls, 1, 'installs the semanage package via pc_pkg_call (instance-addressed, transactional-aware)');
    like($zypper_calls[0], qr/in policycoreutils-python-utils/, 'installs policycoreutils-python-utils');
    ok((grep { /^sudo semanage port -a -t ssh_port_t -p tcp 20223$/ } @instance_calls), 'labels QEMUPORT+1 via $instance->ssh_assert_script_run, with sudo');
    is((grep { $_ eq 'softreboot' } @instance_calls), 1, 'reboots once (on top of pc_pkg_call\'s own reboot) on a transactional system');

    # idempotent: a second call must not repeat any of the work
    @zypper_calls = ();
    @instance_calls = ();
    ssh_allow_openqa_port_selinux($inst);
    is(scalar @zypper_calls, 0, 'second call is a no-op (package already installed/port already allowed)');
    is(scalar @instance_calls, 0, 'second call does not touch the instance again');

    _unset(qw/QEMUPORT/);
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
