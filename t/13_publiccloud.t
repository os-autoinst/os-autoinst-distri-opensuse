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

subtest '[kill_packagekit] pkcon quit succeeds -> no systemctl' => sub {
    my @calls;
    my $inst = Test::MockObject->new;

    $inst->mock('ssh_script_run', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 0;
    });

    publiccloud::utils::kill_packagekit($inst);

    is_deeply \@calls, ['sudo pkcon quit'],
      'only pkcon quit executed when it succeeds';
};

subtest '[kill_packagekit] pkcon quit fails -> stop/disable/mask' => sub {
    my @calls;
    my $inst = Test::MockObject->new;
    my $n = 0;

    $inst->mock('ssh_script_run', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return (++$n == 1) ? 1 : 0;
    });

    publiccloud::utils::kill_packagekit($inst);

    is_deeply \@calls, [
        'sudo pkcon quit',
        'sudo systemctl stop packagekitd',
        'sudo systemctl disable packagekitd',
        'sudo systemctl mask packagekitd',
    ], 'falls back to systemctl stop/disable/mask when pkcon quit fails';
};

subtest '[get_installed_packages_remote] parses rpm -q output and preserves original order subset' => sub {
    my $inst = Test::MockObject->new;
    my @seen;
    $inst->mock('ssh_script_output', sub {
            my ($self, %args) = @_;
            push @seen, \%args;
            return "bash|curl|package zzz is not installed|git|package nope is not installed|";
    });

    my $wanted = [qw(bash curl git zzz)];
    my $got = publiccloud::utils::get_installed_packages_remote($inst, $wanted);

    is scalar(@seen), 1, 'single ssh call';
    like $seen[0]->{cmd}, qr{^rpm -q --qf '%\{NAME\}\|' bash curl git zzz 2>/dev/null$},
      'calls rpm -q with expected qf and packages';
    is_deeply $got, [qw(bash curl git)], 'returns only installed, in original list order';
};

subtest '[get_available_packages_remote] filters out already installed, parses zypper -x info' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');
    my $inst = Test::MockObject->new;
    my @ssh_calls;

    $utils_mock->redefine('get_installed_packages_remote', sub {
            my ($instance, $pkgs) = @_;
            return ['bash'];
    });

    $inst->mock('ssh_script_output', sub {
            my ($self, %args) = @_;
            push @ssh_calls, \%args;
            return join("\n",
                "Information for package curl:",
                "Name        : curl",
                "Version     : 8.7.1",
                "",
                "Information for package git:",
                "Name : git",
                "Version: 2.46.0",
                "",
                "Information for package nope:",
                "Name: nope-but-not-available",
            );
    });

    my $wanted = [qw(bash curl git nope)];
    my $got = publiccloud::utils::get_available_packages_remote($inst, $wanted);

    is scalar(@ssh_calls), 1, 'one zypper info call for not-installed pkgs only';
    like $ssh_calls[0]->{cmd}, qr{^zypper -x info curl git nope 2>/dev/null$},
      'zypper -x info called only for not-installed';
    is_deeply $got, [qw(curl git)], 'returns only exact Name matches that were not installed';
};

subtest '[get_available_packages_remote] returns [] when all already installed' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');
    my $inst = Test::MockObject->new;
    my $called = 0;

    $utils_mock->redefine('get_installed_packages_remote', sub {
            my ($instance, $pkgs) = @_;
            return [@$pkgs];
    });

    $inst->mock('ssh_script_output', sub { $called++ });

    my $got = publiccloud::utils::get_available_packages_remote($inst, [qw(a b)]);
    is_deeply $got, [], 'empty when nothing to check';
    is $called, 0, 'no SSH calls when all installed';
};

subtest '[zypper_add_repo_remote] passes correct cmd and timeout' => sub {
    my $inst = Test::MockObject->new;
    my @seen;
    $inst->mock('ssh_assert_script_run', sub { push @seen, \@_; return 0 });

    publiccloud::utils::zypper_add_repo_remote($inst, 'repo-name', 'http://example.test/repo');

    is scalar(@seen), 1, 'one SSH call';
    my %args = @{$seen[0]}[1 .. $#{$seen[0]}];
    is $args{timeout}, 600, 'timeout 600';
    is $args{cmd}, 'sudo zypper -n addrepo -fG http://example.test/repo repo-name',
      'correct addrepo command';
};

subtest '[zypper_remove_repo_remote] passes correct cmd and timeout' => sub {
    my $inst = Test::MockObject->new;
    my @seen;
    $inst->mock('ssh_assert_script_run', sub { push @seen, \@_; return 0 });

    publiccloud::utils::zypper_remove_repo_remote($inst, 'repo-name');

    is scalar(@seen), 1, 'one SSH call';
    my %args = @{$seen[0]}[1 .. $#{$seen[0]}];
    is $args{timeout}, 600, 'timeout 600';
    is $args{cmd}, 'sudo zypper -n removerepo repo-name',
      'correct removerepo command';
};

subtest '[zypper_install_remote] non-transactional uses zypper in with list/str inputs' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');
    $utils_mock->redefine('is_transactional', sub { 0 });

    my $inst = Test::MockObject->new;
    my @seen;
    $inst->mock('ssh_assert_script_run', sub { my ($self, %a) = @_; push @seen, \%a; return 0 });
    $inst->mock('softreboot', sub { die "should not softreboot in non-transactional" });

    publiccloud::utils::zypper_install_remote($inst, [qw(curl git)]);
    publiccloud::utils::zypper_install_remote($inst, 'bash');

    is scalar(@seen), 2, 'two zypper calls';
    is $seen[0]->{cmd}, 'sudo zypper -n in --no-recommends curl git', 'array input joined';
    is $seen[0]->{timeout}, 600, 'timeout 600';
    is $seen[1]->{cmd}, 'sudo zypper -n in --no-recommends bash', 'scalar input handled';
    is $seen[1]->{timeout}, 600, 'timeout 600';
};

subtest '[zypper_install_remote] transactional uses t-u pkg install and softreboot' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');
    $utils_mock->redefine('is_transactional', sub { 1 });

    my $inst = Test::MockObject->new;
    my @runs;
    my $rebooted = 0;

    $inst->mock('ssh_assert_script_run', sub { my ($self, %a) = @_; push @runs, \%a; return 0 });
    $inst->mock('softreboot', sub { $rebooted++ });

    publiccloud::utils::zypper_install_remote($inst, [qw(x y)]);

    is scalar(@runs), 1, 'one t-u call';
    is $runs[0]->{cmd}, 'sudo transactional-update -n pkg install --no-recommends x y',
      'transactional-update used';
    is $runs[0]->{timeout}, 900, 'timeout 900';
    is $rebooted, 1, 'softreboot called once';
};

subtest '[zypper_install_available_remote] installs only available pkgs' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');

    my @seen_pkgs;
    $utils_mock->redefine('get_available_packages_remote', sub { ['curl', 'git'] });
    $utils_mock->redefine('zypper_install_remote', sub {
            my ($instance, $pkgs) = @_;
            @seen_pkgs = @$pkgs;
            return 1;
    });

    my $inst = Test::MockObject->new;

    publiccloud::utils::zypper_install_available_remote($inst, ['curl', 'git', 'nope']);

    is_deeply \@seen_pkgs, [qw(curl git)], 'installs available subset only';
};

subtest '[zypper_install_available_remote] no-op when nothing available' => sub {
    my $utils_mock = Test::MockModule->new('publiccloud::utils');

    my $called = 0;
    $utils_mock->redefine('get_available_packages_remote', sub { [] });
    $utils_mock->redefine('zypper_install_remote', sub { $called++ });

    publiccloud::utils::zypper_install_available_remote(undef, [qw(a b)]);
    is $called, 0, 'does not call install when nothing available';
};

subtest '[wait_quit_zypper_pc] uses defaults and expected command' => sub {
    my $inst = Test::MockObject->new;
    my @calls;

    $inst->mock('retry_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, {%args};
            return 1;
    });

    publiccloud::utils::wait_quit_zypper_pc($inst);

    is scalar(@calls), 1, 'one call to retry_ssh_command';
    is $calls[0]->{cmd},
      q{pgrep -f "zypper|packagekit|purge-kernels|rpm" && false || true},
      'expected pgrep/false/true command';
    is $calls[0]->{timeout}, 20, 'default timeout=20';
    is $calls[0]->{delay}, 10, 'default delay=10';
    is $calls[0]->{retry}, 120, 'default retry=120';
};

subtest '[wait_quit_zypper_pc] honors custom timeout/delay/retry' => sub {
    my $inst = Test::MockObject->new;
    my $seen;

    $inst->mock('retry_ssh_command', sub {
            my ($self, %args) = @_;
            $seen = {%args};
            return 1;
    });

    publiccloud::utils::wait_quit_zypper_pc($inst,
        timeout => 5, delay => 2, retry => 3);

    is $seen->{cmd},
      q{pgrep -f "zypper|packagekit|purge-kernels|rpm" && false || true},
      'same command with custom args';
    is $seen->{timeout}, 5, 'custom timeout applied';
    is $seen->{delay}, 2, 'custom delay applied';
    is $seen->{retry}, 3, 'custom retry applied';
};

subtest '[wait_quit_zypper_pc] succeeds on 5th attempt (4 fail + 1 success)' => sub {
    my $expected_cmd = q{pgrep -f "zypper|packagekit|purge-kernels|rpm" && false || true};

    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('retry_ssh_command', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
                last if $calls == 5;
            }
            return 1;
    });

    my $rc = publiccloud::utils::wait_quit_zypper_pc($inst, retry => 5, delay => 0, timeout => 1);

    ok($rc, 'returned success');
    is($calls, 5, 'performed 5 attempts (4 fail + 1 success)');
    is($seen{cmd}, $expected_cmd, 'used expected pgrep command');
    is($seen{retry}, 5, 'retry=5 passed');
    is($seen{delay}, 0, 'delay=0 passed');
    is($seen{timeout}, 1, 'timeout=1 passed');
};

subtest '[wait_quit_zypper_pc] times out after 5 failures' => sub {
    my $expected_cmd = q{pgrep -f "zypper|packagekit|purge-kernels|rpm" && false || true};

    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('retry_ssh_command', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
            }
            die "retries exhausted after $args{retry} attempts\n";
    });

    my $err;
    eval {
        publiccloud::utils::wait_quit_zypper_pc($inst, retry => 5, delay => 0, timeout => 1);
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

done_testing;
