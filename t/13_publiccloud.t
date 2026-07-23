use strict;
use warnings;


use Test::More;
use Test::MockObject;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any);
use testapi 'set_var';

use publiccloud::azure;
use publiccloud::instance;
use publiccloud::zypper qw(pc_wait_quit pc_pkg_call);

sub _unset { for my $k (@_) { set_var($k, undef) } }

subtest '[get_blob_name]' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('SOMETHING.vhdfixed.xz');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    _unset('PUBLIC_CLOUD_AZURE_SKU');
};

subtest '[get_blob_name] without .xz' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('SOMETHING.vhdfixed');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    _unset('PUBLIC_CLOUD_AZURE_SKU');
};

subtest '[get_blob_name] with URL' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('https://download.somewhere.org/SUSE:/SLE-15-SP5:/Update:/PubClouds/images/SOMETHING.vhdfixed.xz');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    _unset('PUBLIC_CLOUD_AZURE_SKU');
};

subtest '[get_blob_name] file name too short' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res;
    eval { $res = $provider->get_blob_name('.xz') };
    is $res, undef, "The image name is too short.";

    _unset('PUBLIC_CLOUD_AZURE_SKU');
};

subtest '[get_blob_uri]' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    set_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'SOMEWHERE');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_uri('SOMETHING.vhdfixed.xz');
    is $res, 'https://SOMEWHERE.blob.core.windows.net/sle-images/SOMETHING.vhd', "The image uri is properly composed";

    _unset(qw/PUBLIC_CLOUD_AZURE_SKU PUBLIC_CLOUD_STORAGE_ACCOUNT/);
};

subtest '[generate_basename]' => sub {
    set_var('DISTRI', 'AAA');
    set_var('VERSION', 'BBB');
    set_var('FLAVOR', 'CCC');
    set_var('ARCH', 'x86_64');

    my $provider = publiccloud::azure->new();

    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $res = $provider->generate_basename();
    is $res, 'AAA-BBB-CCC-x64';

    set_var('PUBLIC_CLOUD_ARCH', 'ZZZ');

    $res = $provider->generate_basename();
    is $res, 'AAA-BBB-CCC-Arm64';

    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    $res = $provider->generate_basename();
    is $res, 'AAA-BBB-CCC-x86_64';

    _unset(qw/PUBLIC_CLOUD_ARCH PUBLIC_CLOUD DISTRI VERSION FLAVOR ARCH/);
};

subtest '[generate_azure_image_definition]' => sub {
    set_var('DISTRI', 'AAA');
    set_var('VERSION', 'BBB');
    set_var('FLAVOR', 'CCC');
    set_var('ARCH', 'x86_64');
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen1');

    my $provider = publiccloud::azure->new();

    my $res = $provider->generate_azure_image_definition();
    is $res, 'AAA-BBB-CCC-X64-GEN1';

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);

    $res = $provider->generate_azure_image_definition();
    is $res, 'AAA-BBB-CCC-X64-GEN2';

    set_var('PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION', 'ABC');

    $res = $provider->generate_azure_image_definition();
    is $res, 'ABC', 'PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION can be used to overwrite the full name';

    set_var('PUBLIC_CLOUD', undef);
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    set_var('PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION', undef);
    set_var('DISTRI', undef);
    set_var('VERSION', undef);
    set_var('FLAVOR', undef);
    set_var('ARCH', undef);
};

subtest '[az_sku]' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);

    my $provider = publiccloud::azure->new();

    my $res = $provider->az_sku();
    is $res, "gen2";

    $res = $provider->az_sku("");
    is $res, "";

    $res = $provider->az_sku(0);
    is $res, '0';

    $res = $provider->az_sku("ALPHA");
    is $res, 'ALPHA';

    set_var('PUBLIC_CLOUD_AZURE_SKU', 'GEN1');

    $res = $provider->az_sku();
    is $res, "GEN1";

    $res = $provider->az_sku("");
    is $res, 'GEN1';

    $res = $provider->az_sku("BETA");
    is $res, 'GEN1';

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
};

subtest '[az_arch]' => sub {
    set_var('PUBLIC_CLOUD_ARCH', undef);
    set_var('ARCH', 'x86_64');

    my $provider = publiccloud::azure->new();

    my $res = $provider->az_arch();
    is $res, 'x64';

    set_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    set_var('ARCH', 'ZZZZ');

    $res = $provider->az_arch();
    is $res, 'x64';

    set_var('PUBLIC_CLOUD_ARCH', 'ARM');

    $res = $provider->az_arch();
    is $res, 'Arm64';

    set_var('PUBLIC_CLOUD_ARCH', undef);
    set_var('ARCH', undef);
};

subtest '[generate_img_version]' => sub {
    set_var('PUBLIC_CLOUD_BUILD', '1.23');
    set_var('PUBLIC_CLOUD_BUILD_KIWI', '4.56');

    my $provider = publiccloud::azure->new();

    my $res = $provider->generate_img_version();
    is $res, '1.23.456';

    set_var('PUBLIC_CLOUD_BUILD', undef);
    set_var('PUBLIC_CLOUD_BUILD_KIWI', undef);
};

subtest '[find_img] resource group does not exist' => sub {
    my $provider_azure_mock = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $provider_azure_mock->redefine(resource_group_exist => sub { return undef; });

    my $provider = publiccloud::azure->new();

    my $res = $provider->find_img('SOMETHING');
    is $res, undef;
};

subtest '[find_img] wrong image name' => sub {
    my $provider_azure_mock = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $provider_azure_mock->redefine(resource_group_exist => sub { return 1; });
    $provider_azure_mock->redefine(img_blob_exists => sub { return 1; });
    $provider_azure_mock->redefine(get_image_version => sub { return '/something/to/test.1.2.3'; });

    my $provider = publiccloud::azure->new();

    my $res;
    eval { $res = $provider->find_img('') };
    is $res, undef, 'The image name is not valid.';
};

subtest '[find_img] blob not found' => sub {
    my $provider_azure_mock = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $provider_azure_mock->redefine(resource_group_exist => sub { return 1; });
    $provider_azure_mock->redefine(img_blob_exists => sub { return 0; });
    $provider_azure_mock->redefine(get_image_version => sub { return '/something/to/test.1.2.3'; });

    my $provider = publiccloud::azure->new();

    my $res = $provider->find_img('SOMETHING.vhd');
    is $res, undef, 'The blob has not been found.'; };

subtest '[find_img] - image version not found' => sub {
    my $provider_azure_mock = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $provider_azure_mock->redefine(resource_group_exist => sub { return 1; });
    $provider_azure_mock->redefine(img_blob_exists => sub { return 1; });
    $provider_azure_mock->redefine(get_image_version => sub { return 0; });

    my $provider = publiccloud::azure->new();

    my $res = $provider->find_img('SOMETHING.vhd');
    is $res, 0, 'The image version has not been found.';
};

subtest '[pc_wait_quit] uses defaults and expected command' => sub {
    my $inst = Test::MockObject->new;
    my @calls;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            push @calls, {%args};
            return 1;
    });

    pc_wait_quit($inst);

    is scalar(@calls), 1, 'one call to ssh_script_retry';
    is $calls[0]->{cmd},
      q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"},
      'expected pgrep/false/true command';
    is $calls[0]->{timeout}, 20, 'default timeout=20';
    is $calls[0]->{delay}, 10, 'default delay=10';
    is $calls[0]->{retry}, 120, 'default retry=120';
};

subtest '[pc_wait_quit] honors custom timeout/delay/retry' => sub {
    my $inst = Test::MockObject->new;
    my $seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            $seen = {%args};
            return 1;
    });

    pc_wait_quit($inst,
        timeout => 5, delay => 2, retry => 3);

    is $seen->{cmd},
      q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"},
      'same command with custom args';
    is $seen->{timeout}, 5, 'custom timeout applied';
    is $seen->{delay}, 2, 'custom delay applied';
    is $seen->{retry}, 3, 'custom retry applied';
};

subtest '[pc_wait_quit] succeeds on 5th attempt (4 fail + 1 success)' => sub {
    my $expected_cmd = q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"};

    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
                last if $calls == 5;
            }
            return 1;
    });

    my $rc = pc_wait_quit($inst, retry => 5, delay => 0, timeout => 1);

    ok($rc, 'returned success');
    is($calls, 5, 'performed 5 attempts (4 fail + 1 success)');
    is($seen{cmd}, $expected_cmd, 'used expected pgrep command');
    is($seen{retry}, 5, 'retry=5 passed');
    is($seen{delay}, 0, 'delay=0 passed');
    is($seen{timeout}, 1, 'timeout=1 passed');
};

subtest '[pc_wait_quit] times out after 5 failures' => sub {
    my $expected_cmd = q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"};

    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
            }
            die "retries exhausted after $args{retry} attempts\n";
    });

    my $err;
    eval {
        pc_wait_quit($inst, retry => 5, delay => 0, timeout => 1);
        1;
    } or $err = $@;

    like($err, qr/retries exhausted after 5 attempts/, 'died with timeout message');
    is($calls, 5, 'performed 5 failing attempts');
    is($seen{cmd}, $expected_cmd, 'used expected pgrep command');
    is($seen{retry}, 5, 'retry=5 passed');
    is($seen{delay}, 0, 'delay=0 passed');
    is($seen{timeout}, 1, 'timeout=1 passed');
};

sub _capture_pkg_call {
    my ($transactional, $cmd, %opts) = @_;
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(is_transactional => sub { $transactional });

    my %captured;
    $mod->redefine(pc_transactional_call => sub {
            my ($instance, $c, %o) = @_;
            $captured{transactional} = $c;
            return 0;
    });
    $mod->redefine(pc_zypper_call => sub {
            my ($instance, $c, %o) = @_;
            $captured{zypper} = $c;
            return 0;
    });

    my $inst = Test::MockObject->new;
    pc_pkg_call($inst, $cmd, %opts);
    return \%captured;
}

# These assert that zypper *command* options stay attached to the verb and are
# never hoisted into transactional-update's global slot. Regression guard for
# the case where `zypper in -y curl` became `transactional-update -y pkg ...`,
# with -y being an invalid transactional-update global option.

# Run pc_pkg_call with is_transactional() forced to $transactional and capture
# the command string handed to the transactional / plain-zypper layer.
subtest '[pc_pkg_call] command flags stay with verb, not hoisted to global' => sub {
    my %cases = (
        'in -y docker' => 'pkg install -y docker',
        'in --force-resolution -y curl' => 'pkg install --force-resolution -y curl',
        'in -r net_perf iperf' => 'pkg install -r net_perf iperf',
        'install --no-recommends foo bar' => 'pkg install --no-recommends foo bar',
        'update -y' => 'pkg update -y',
        'in libcontainers-common' => 'pkg install libcontainers-common',
        'rm -u oldpkg' => 'pkg remove -u oldpkg',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
        ok !defined $cap->{zypper}, "[$input] did not fall through to plain zypper";
    }
};

# The core regression guard: a zypper *command* flag placed BEFORE the verb must
# NOT be hoisted into transactional-update's global slot (where it is invalid).
# The old loop swept every leading dash-token into @flags; these cases prove the
# command flag now travels with the verb instead.
subtest '[pc_pkg_call] pre-verb command flag is kept with the verb' => sub {
    my %cases = (
        '-y in docker' => 'pkg install -y docker',
        '--force-resolution in curl' => 'pkg install --force-resolution curl',
        '--no-recommends install foo' => 'pkg install --no-recommends foo',
        # only the genuine global (-n) stays global; -y moves to the verb
        '-n -y in curl' => '-n pkg install -y curl',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
    }
};

subtest '[pc_pkg_call] bare top-level verbs translate without pkg wrapper' => sub {
    my %cases = (
        'up' => 'up',
        'dup' => 'dup',
        'dist-upgrade' => 'dup',
        'patch' => 'patch',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
    }
};

subtest '[pc_pkg_call] real transactional-update global opt is hoisted' => sub {
    # A genuine global option placed before the verb belongs in the global slot.
    my $cap = _capture_pkg_call(1, '-n in -y curl');
    is $cap->{transactional}, '-n pkg install -y curl',
      'global -n stays global; command -y stays with verb';
};

subtest '[pc_pkg_call] non-translatable verb falls through to plain zypper' => sub {
    my $cap = _capture_pkg_call(1, 'info foo');
    is $cap->{zypper}, 'info foo', 'info passed verbatim to pc_zypper_call';
    ok !defined $cap->{transactional}, 'info not routed through transactional-update';
};

subtest '[pc_pkg_call] non-transactional system always uses plain zypper' => sub {
    my $cap = _capture_pkg_call(0, 'in -y docker');
    is $cap->{zypper}, 'in -y docker', 'verbatim zypper on non-transactional host';
    ok !defined $cap->{transactional}, 'no transactional-update translation';
};

# --- do_systemd_analyze_time boot-time race (poo#203817) ----------------------
#
# prepare_instance probes `systemd-analyze time` right after SSH is up. On a
# freshly-launched Public Cloud instance boot may not be finished yet, so the
# probe returns "Bootup is not yet finished (...FinishTimestampMonotonic=0)".
# The routine must keep polling until "Startup finished in" appears, must not
# discard a result that arrives near the timeout, and must fall back to the
# WARN + (0,0) path only when boot genuinely never finishes.

# Drive do_systemd_analyze_time with a scripted sequence of `systemd-analyze
# time` outputs and a controllable fake clock (so no real sleeping happens and
# the timeout is reached deterministically). Each element of @$time_outputs is
# returned by successive `systemd-analyze time` calls; the last element repeats
# once the list is exhausted.
sub _run_systemd_analyze {
    my ($time_outputs, %args) = @_;
    my $blame_output = delete $args{blame_output}
      // "10.000s some.service\n5.000s other.service";

    # Test::Mock::Time advances mocked time() by each sleep() the routine does,
    # so the loop's `time() - $start_time < $timeout` guard is deterministic and
    # fast. Capture the fake start time to report elapsed time back to callers.
    my $clock_start = time();

    my @time_seq = @$time_outputs;
    my @time_cmds;
    my $inst = publiccloud::instance->new();
    my $mocked = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $mocked->redefine(ssh_script_output => sub {
            my ($self, %a) = @_;
            if ($a{cmd} eq 'systemd-analyze blame') {
                return $blame_output;
            }
            push @time_cmds, $a{cmd};
            return @time_seq > 1 ? shift(@time_seq) : $time_seq[0];
    });
    $mocked->redefine(ssh_script_run => sub { return 0; });
    $mocked->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @ret = $inst->do_systemd_analyze_time(%args);
    return {ret => \@ret, time_calls => scalar(@time_cmds), final_time => time() - $clock_start};
}

subtest '[do_systemd_analyze_time] early success returns parsed times' => sub {
    my $r = _run_systemd_analyze(
        ['Startup finished in 1.000s (kernel) + 2.000s (initrd) + 3.000s (userspace) = 6.000s'],
        timeout => 300);

    my ($analyze, $blame) = @{$r->{ret}};
    ok ref($analyze) eq 'HASH', 'analyze result is a hashref (not the (0,0) failure)';
    cmp_ok $analyze->{overall}, '==', 6, 'overall boot time parsed';
    cmp_ok $analyze->{userspace}, '==', 3, 'userspace boot time parsed';
    is $r->{time_calls}, 1, 'succeeded on the first probe';
};

subtest '[do_systemd_analyze_time] retries while "Bootup is not yet finished"' => sub {
    my $not_finished = 'Bootup is not yet finished (org.freedesktop.systemd1.Manager.FinishTimestampMonotonic=0)';
    my $r = _run_systemd_analyze(
        [$not_finished, $not_finished, $not_finished,
            'Startup finished in 1.000s (kernel) + 2.000s (initrd) + 3.000s (userspace) = 6.000s'],
        timeout => 300);

    my ($analyze) = @{$r->{ret}};
    ok ref($analyze) eq 'HASH', 'result parsed after boot finishes';
    cmp_ok $analyze->{overall}, '==', 6, 'overall boot time parsed after retries';
    is $r->{time_calls}, 4, 'polled until boot finished (3 not-finished + 1 success)';
};

subtest '[do_systemd_analyze_time] late success near timeout is NOT discarded' => sub {
    # Regression guard for the trailing-sleep bug: a successful result arriving
    # on the final poll (just under the timeout) must be returned, not thrown
    # away because the clock crossed the timeout during that poll.
    my $not_finished = 'Bootup is not yet finished (org.freedesktop.systemd1.Manager.FinishTimestampMonotonic=0)';
    # timeout=20, sleep 5 per iteration: polls happen at t=0,5,10,15; success on
    # the 4th poll (t=15). The old code's trailing sleep would push t to 20 and
    # discard this valid result.
    my $r = _run_systemd_analyze(
        [$not_finished, $not_finished, $not_finished,
            'Startup finished in 1.000s (kernel) + 2.000s (initrd) + 3.000s (userspace) = 6.000s'],
        timeout => 20);

    my ($analyze) = @{$r->{ret}};
    ok ref($analyze) eq 'HASH', 'late-but-valid result is returned, not discarded';
    cmp_ok $analyze->{overall}, '==', 6, 'overall boot time parsed on late success';
};

subtest '[do_systemd_analyze_time] persistent not-finished ends in WARN + (0,0)' => sub {
    my $not_finished = 'Bootup is not yet finished (org.freedesktop.systemd1.Manager.FinishTimestampMonotonic=0)';
    my $r = _run_systemd_analyze([$not_finished], timeout => 20);

    is_deeply $r->{ret}, [0, 0], 'returns (0,0) when boot never finishes';
    ok $r->{final_time} >= 20, 'polled for the full timeout window before giving up';
};

subtest '[do_systemd_analyze_time] SSH login banner does not break parsing' => sub {
    # Regression guard for the second failure seen in the poo#203817 VR: SSH
    # prepends a login banner / MOTD to the command output, so "Startup finished
    # in" is NOT on the first line. extract_analyze_time must pick the timing
    # line by content, and extract_blame_time must skip banner lines, instead of
    # failing with "Unable to parse systemd time ''" and dying.
    my $banner = join("\n",
        "",
        "Welcome to SUSE Linux Enterprise Server 15 SP7  (x86_64)",
        "",
        "Authorized users only. All activity may be monitored and reported.",
    );
    my $analyze_out = $banner . "\n"
      . "Startup finished in 2.406s (kernel) + 13.116s (initrd) + 19.353s (userspace) = 34.876s \n"
      . "graphical.target reached after 19.290s in userspace.";
    my $blame_out = $banner . "\n"
      . "14.852s some.device\n" . "5.000s other.service";

    my $r = _run_systemd_analyze([$analyze_out], timeout => 300, blame_output => $blame_out);

    my ($analyze, $blame) = @{$r->{ret}};
    ok ref($analyze) eq 'HASH', 'analyze parsed despite banner (no die)';
    cmp_ok $analyze->{overall}, '==', 34.876, 'overall boot time parsed from banner-prefixed output';
    cmp_ok $analyze->{userspace}, '==', 19.353, 'userspace boot time parsed';
    ok ref($blame) eq 'HASH', 'blame parsed despite banner';
    cmp_ok $blame->{'some.device'}, '==', 14.852, 'blame entry parsed, banner skipped';
    ok !exists $blame->{'reported.'}, 'banner text not mistaken for a blame entry';
};

# --- publiccloud::azure pure functions ----------------------------------------

subtest '[decode_azure_json] strips color codes and decodes' => sub {
    my $colored = "\e[32m{\"name\": \"foo\", \"n\": 7}\e[0m";
    my $obj = publiccloud::azure::decode_azure_json($colored);
    is(ref $obj, 'HASH', 'returns decoded hashref');
    is($obj->{name}, 'foo', 'string value decoded after colorstrip');
    is($obj->{n}, 7, 'numeric value decoded');
};

subtest '[parse_instance_id] azure resource id parsing' => sub {
    my $provider = publiccloud::azure->new();

    my $id = '/subscriptions/SUB-123/resourceGroups/RG-456/providers/Microsoft.Compute/virtualMachines/my-vm';
    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { $id });
    my $res = $provider->parse_instance_id($inst);
    is($res->{subscription}, 'SUB-123', 'subscription parsed');
    is($res->{resource_group}, 'RG-456', 'resource_group parsed');
    is($res->{vm_name}, 'my-vm', 'vm_name parsed');

    my $bad = Test::MockObject->new;
    $bad->mock(instance_id => sub { 'i-0123456789abcdef0' });
    is($provider->parse_instance_id($bad), undef, 'non-azure id returns undef');
};

subtest '[generate_image_tags] tag composition' => sub {
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $azure->redefine(get_current_job_id => sub { 4242 });
    set_var('OPENQA_URL', 'https://openqa.example.com/');
    set_var('PUBLIC_CLOUD_KEEP_IMG', undef);

    my $tags = publiccloud::azure::generate_image_tags();
    like($tags, qr{openqa_created_by=openqa\.example\.com/t4242}, 'created_by tag composed and url trimmed');
    like($tags, qr{openqa_var_job_id=4242}, 'job id tag present');
    unlike($tags, qr{pcw_ignore}, 'no pcw_ignore tag without KEEP_IMG');

    set_var('PUBLIC_CLOUD_KEEP_IMG', '1');
    my $tags2 = publiccloud::azure::generate_image_tags();
    like($tags2, qr{pcw_ignore=1}, 'pcw_ignore tag added when KEEP_IMG=1');

    _unset(qw/OPENQA_URL OPENQA_HOSTNAME PUBLIC_CLOUD_KEEP_IMG/);
};

subtest '[get_image_definition] finds matching definition' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $azure->redefine(generate_azure_image_definition => sub { 'MY-DEF' });
    $azure->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    $azure->redefine(script_output => sub { '[{"name":"OTHER"},{"name":"MY-DEF"}]' });
    is($provider->get_image_definition('rg', 'gal'), 'MY-DEF', 'returns matching definition name');

    $azure->redefine(script_output => sub { '[{"name":"OTHER"}]' });
    is($provider->get_image_definition('rg', 'gal'), undef, 'undef when no match');

    $azure->redefine(script_output => sub { '' });
    is($provider->get_image_definition('rg', 'gal'), undef, 'undef on empty output');
};

# --- publiccloud::azure mockable instance methods -----------------------------

subtest '[get_state_from_instance] parses PowerState' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $azure->redefine(script_output => sub { '{"code":"PowerState/running","displayStatus":"VM running"}' });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { '/subscriptions/x/resourceGroups/y/providers/Microsoft.Compute/virtualMachines/z' });
    is($provider->get_state_from_instance($inst), 'running', 'extracts state after PowerState/');

    $azure->redefine(script_output => sub { '{"code":"ProvisioningState/succeeded"}' });
    throws_ok { $provider->get_state_from_instance($inst) }
    qr/Expect PowerState/, 'dies when not a PowerState code';
};

subtest '[query_metadata] returns metadata server data' => sub {
    my $provider = publiccloud::azure->new();
    my $inst = Test::MockObject->new;
    my @calls;
    $inst->mock(ssh_script_output => sub { my ($s, $c) = @_; push @calls, $c; return '10.1.2.3' });

    my $data = $provider->query_metadata($inst, ifNum => 0, addrCount => 0);
    note("\n  -->  " . join("\n  -->  ", @calls));
    is($data, '10.1.2.3', 'returns metadata payload');
    ok((any { /169\.254\.169\.254/ } @calls), 'queries the cloud metadata IP');
    ok((any { m{network/interface/0/ipv4/ipAddress/0/privateIpAddress} } @calls), 'composes metadata path');

    $inst->mock(ssh_script_output => sub { '' });
    throws_ok { $provider->query_metadata($inst, ifNum => 0, addrCount => 0) }
    qr/Failed to get interface IPs/, 'dies on empty metadata response';
};

subtest '[start_instance] starts a stopped instance' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    my @asr;
    $azure->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });
    $azure->redefine(get_state_from_instance => sub { 'stopped' });
    $azure->redefine(get_public_ip => sub { '203.0.113.9' });

    my $newip;
    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'vm-id' });
    $inst->mock(resource_group => sub { 'rg' });
    $inst->mock(public_ip => sub { $newip = $_[1] if @_ > 1; return $newip });

    $provider->start_instance($inst);
    note("\n  -->  " . join("\n  -->  ", @asr));
    ok((any { /az vm start --ids 'vm-id'/ } @asr), 'issues az vm start');
    is($newip, '203.0.113.9', 'updates instance public_ip after start');

    $azure->redefine(get_state_from_instance => sub { 'running' });
    throws_ok { $provider->start_instance($inst) }
    qr/start a running instance/, 'refuses to start a running instance';
};

subtest '[stop_instance] stops a running instance' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    my @asr;
    $azure->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });
    $azure->redefine(get_public_ip => sub { '203.0.113.9' });
    # first call: running, second: stopped (loop exits)
    my @states = ('running', 'stopped');
    $azure->redefine(get_state_from_instance => sub { shift @states // 'stopped' });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'vm-id' });
    $inst->mock(resource_group => sub { 'rg' });
    $inst->mock(public_ip => sub { '203.0.113.9' });

    $provider->stop_instance($inst);
    note("\n  -->  " . join("\n  -->  ", @asr));
    ok((any { /az vm stop --ids 'vm-id'/ } @asr), 'issues az vm stop');
};

subtest '[stop_instance] dies on outdated instance object' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);
    $azure->redefine(get_public_ip => sub { '203.0.113.9' });

    my $inst = Test::MockObject->new;
    $inst->mock(instance_id => sub { 'vm-id' });
    $inst->mock(resource_group => sub { 'rg' });
    $inst->mock(public_ip => sub { '198.51.100.1' });    # mismatch

    throws_ok { $provider->stop_instance($inst) }
    qr/Outdated instance object/, 'dies when cached IP differs from live IP';
};

subtest '[resource_group_exist] boolean from az output' => sub {
    my $provider = publiccloud::azure->new();
    my $azure = Test::MockModule->new('publiccloud::azure', no_auto => 1);

    $azure->redefine(script_output_retry => sub { '{"name":"openqa-upload"}' });
    is($provider->resource_group_exist(), 1, 'non-empty output => exists');

    $azure->redefine(script_output_retry => sub { '[]' });
    is($provider->resource_group_exist(), 0, 'empty array output => not exists');
};

done_testing;
