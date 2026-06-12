use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi 'set_var';

use publiccloud::azure;
use publiccloud::utils;
use publiccloud::zypper qw(pc_wait_quit pc_pkg_call);

sub _unset { for my $k (@_) { set_var($k, undef) } }

subtest '[get_blob_name]' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('SOMETHING.vhdfixed.xz');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
};

subtest '[get_blob_name] without .xz' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('SOMETHING.vhdfixed');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
};

subtest '[get_blob_name] with URL' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_name('https://download.somewhere.org/SUSE:/SLE-15-SP5:/Update:/PubClouds/images/SOMETHING.vhdfixed.xz');
    is $res, 'SOMETHING.vhd', "The image name is properly composed";

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
};

subtest '[get_blob_name] file name too short' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');

    my $provider = publiccloud::azure->new();

    my $res;
    eval { $res = $provider->get_blob_name('.xz') };
    is $res, undef, "The image name is too short.";

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
};

subtest '[get_blob_uri]' => sub {
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    set_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'SOMEWHERE');

    my $provider = publiccloud::azure->new();

    my $res = $provider->get_blob_uri('SOMETHING.vhdfixed.xz');
    is $res, 'https://SOMEWHERE.blob.core.windows.net/sle-images/SOMETHING.vhd', "The image uri is properly composed";

    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
    set_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', undef);
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

    set_var('PUBLIC_CLOUD_ARCH', undef);
    set_var('PUBLIC_CLOUD', undef);
    set_var('DISTRI', undef);
    set_var('VERSION', undef);
    set_var('FLAVOR', undef);
    set_var('ARCH', undef);
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
      q{! pgrep -a "zypper|packagekit|purge-kernels|rpm"},
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
      q{! pgrep -a "zypper|packagekit|purge-kernels|rpm"},
      'same command with custom args';
    is $seen->{timeout}, 5, 'custom timeout applied';
    is $seen->{delay}, 2, 'custom delay applied';
    is $seen->{retry}, 3, 'custom retry applied';
};

subtest '[pc_wait_quit] succeeds on 5th attempt (4 fail + 1 success)' => sub {
    my $expected_cmd = q{! pgrep -a "zypper|packagekit|purge-kernels|rpm"};

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
    my $expected_cmd = q{! pgrep -a "zypper|packagekit|purge-kernels|rpm"};

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

subtest '[is_byos] via set_var' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'SLES-15-SP6-BYOS');
    ok publiccloud::utils::is_byos(), 'BYOS detected (upper)';

    set_var('FLAVOR', 'sles-something-byos');
    ok publiccloud::utils::is_byos(), 'BYOS detected (lower, /byos/i)';

    set_var('FLAVOR', 'SLES-15-SP6-On-Demand');
    ok !publiccloud::utils::is_byos(), 'not BYOS when FLAVOR lacks token';

    set_var('PUBLIC_CLOUD', 0);
    ok !publiccloud::utils::is_byos(), 'not BYOS outside public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};

subtest '[is_ondemand] via set_var' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'On-Demand-ish');
    ok publiccloud::utils::is_ondemand(), 'on-demand when not BYOS';

    set_var('FLAVOR', 'BYOS');
    ok !publiccloud::utils::is_ondemand(), 'not on-demand when BYOS';

    set_var('PUBLIC_CLOUD', 0);
    ok !publiccloud::utils::is_ondemand(), 'not on-demand outside public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};

subtest '[provider checks] via set_var' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok publiccloud::utils::is_ec2(), 'EC2 true';
    ok !publiccloud::utils::is_azure(), 'AZURE false';
    ok !publiccloud::utils::is_gce(), 'GCE false';

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok publiccloud::utils::is_azure(), 'AZURE true';
    ok !publiccloud::utils::is_ec2(), 'EC2 false';
    ok !publiccloud::utils::is_gce(), 'GCE false';

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    ok publiccloud::utils::is_gce(), 'GCE true';
    ok !publiccloud::utils::is_ec2(), 'EC2 false';
    ok !publiccloud::utils::is_azure(), 'AZURE false';

    set_var('PUBLIC_CLOUD', 0);
    ok !publiccloud::utils::is_ec2(), 'EC2 false when not public cloud';
    ok !publiccloud::utils::is_azure(), 'AZURE false when not public cloud';
    ok !publiccloud::utils::is_gce(), 'GCE false when not public cloud';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER/);
};

subtest '[flavor flags] CHOST & Hardened via set_var' => sub {
    set_var('PUBLIC_CLOUD', 1);

    set_var('FLAVOR', 'SLE-CHOST-15-SP6');
    ok publiccloud::utils::is_container_host(), 'CHOST detected';

    set_var('FLAVOR', 'SLE-Hardened-15-SP6');
    ok publiccloud::utils::is_hardened(), 'Hardened detected';

    set_var('FLAVOR', 'SLE-Whatever');
    ok !publiccloud::utils::is_container_host(), 'CHOST not detected';
    ok !publiccloud::utils::is_hardened(), 'Hardened not detected';

    set_var('PUBLIC_CLOUD', 0);
    set_var('FLAVOR', 'SLE-CHOST-15-SP6');
    ok !publiccloud::utils::is_container_host(), 'CHOST requires public cloud';
    set_var('FLAVOR', 'SLE-Hardened-15-SP6');
    ok !publiccloud::utils::is_hardened(), 'Hardened requires public cloud';

    _unset(qw/PUBLIC_CLOUD FLAVOR/);
};


subtest '[is_cloudinit_supported] via set_var only' => sub {
    set_var('PUBLIC_CLOUD', 1);
    set_var('DISTRI', 'sle');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok publiccloud::utils::is_cloudinit_supported(),
      'AZURE + sle => supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok publiccloud::utils::is_cloudinit_supported(),
      'EC2 + sle => supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
    ok !publiccloud::utils::is_cloudinit_supported(),
      'GCE + sle => not supported';

    set_var('DISTRI', 'sle-micro');

    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok !publiccloud::utils::is_cloudinit_supported(),
      'AZURE + sle-micro => NOT supported';

    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    ok !publiccloud::utils::is_cloudinit_supported(),
      'EC2 + sle-micro => NOT supported';

    set_var('PUBLIC_CLOUD', 0);
    set_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    ok !publiccloud::utils::is_cloudinit_supported(),
      'not public cloud => NOT supported';

    _unset(qw/PUBLIC_CLOUD PUBLIC_CLOUD_PROVIDER DISTRI/);
};

# --- pc_pkg_call -> transactional-update translation ---------------------------
#
# These assert that zypper *command* options stay attached to the verb and are
# never hoisted into transactional-update's global slot. Regression guard for
# the case where `zypper in -y curl` became `transactional-update -y pkg ...`,
# with -y being an invalid transactional-update global option.

# Run pc_pkg_call with is_transactional() forced to $transactional and capture
# the command string handed to the transactional / plain-zypper layer.
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

done_testing;
