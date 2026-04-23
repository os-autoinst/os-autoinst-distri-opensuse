# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Kernel Selftests helper functions
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::utils;

use base Exporter;
use testapi;
use strict;
use warnings;
use utils;
use Kselftests::parser;
use LTP::WhiteList;
use version_utils qw(is_sle has_selinux is_tumbleweed);
use base 'opensusebasetest';
use File::Basename qw(basename);
use repo_tools qw(add_qa_head_repo);
use registration qw(add_suseconnect_product get_addon_fullname);
use package_utils qw(install_package install_available_packages);
use utils qw(write_sut_file systemctl);

our @EXPORT = qw(
  install_kselftests
  post_process_single
  post_process
  validate_kconfig
);

sub build
{
    my ($targets, $source_dir) = @_;

    my $version = script_output('uname -r');
    $source_dir //= "/lib/modules/$version/source";
    my $build_dir = "/lib/modules/$version/build";

    # Lock kernel-source/syms to their already-installed versions if present (e.g. pre-installed
    # by install_kotd at the same version as the running kernel), so the devel_kernel pattern
    # cannot upgrade them to a mismatched version pulled from a rolling repo like KOTD.
    my $lock_kernel_pkgs = !script_run('rpm -q kernel-source kernel-syms');
    zypper_call('al kernel-source kernel-syms') if $lock_kernel_pkgs;
    zypper_call('install -t pattern --recommends devel_kernel');    # no trup support for now
    zypper_call('rl kernel-source kernel-syms') if $lock_kernel_pkgs;

    my $jobs = get_var('KSELFTEST_BUILD_JOBS', '$(getconf _NPROCESSORS_ONLN)');
    my $build_env = get_var('KSELFTEST_BUILD_ENV', '');
    my $make_cmd = "make -j$jobs -C $source_dir/tools/testing/selftests install O=$build_dir SKIP_TARGETS= TARGETS=$targets FORCE_TARGETS=1 $build_env";
    $make_cmd =~ s/\s+$//;

    assert_script_run("make -j$jobs -C $source_dir headers O=$build_dir $build_env");
    assert_script_run($make_cmd, 7200);
    assert_script_run("cd $build_dir/kselftest/kselftest_install");
}

sub install_from_git
{
    my ($collection) = @_;

    my $git_tree = get_var('KERNEL_GIT_TREE', 'https://github.com/torvalds/linux.git');
    my $git_tag = get_var('KERNEL_GIT_TAG', '');

    install_package('git', trup_continue => 1);
    assert_script_run("git clone --depth 1 --single-branch --branch master $git_tree linux", 240);

    assert_script_run("cd ./linux");

    if ($git_tag ne '') {
        assert_script_run("git fetch --unshallow --tags", 7200);
        assert_script_run("git checkout $git_tag");
    }

    record_info("GIT Commit", script_output("git --no-pager log -1 --oneline"));

    if (is_sle && $collection eq 'livepatch') {
        my $patch = 'selftests-livepatch-Ignore-NO_SUPPORT-line-in-dmesg.patch';
        assert_script_run("curl -O " . autoinst_url("/data/kernel/$patch"));
        assert_script_run("git apply $patch");
    }

    build($collection, '.');
}

sub install_from_repo
{
    zypper_ar(get_required_var('KSELFTEST_REPO'), name => 'kselftests', priority => 1, no_gpg_check => 1);
    install_package('kselftests kernel-devel', trup_continue => 1);

    # When using the `kselftests` package from a repository, make sure the KMP subpackage containing the test kernel modules
    # were built against the same kernel version the SUT is currently running.
    my ($kver) = script_output('uname -r') =~ /(.*)-\w*/;
    my ($kmpver) = script_output("rpm -q --qf '%{VERSION}\n' kselftests-kmp-default") =~ /\d*_k(.*)/;
    die 'Could not extract kernel or KMP suffix' unless defined $kver && defined $kmpver;
    $kver =~ s/_/-/g;
    $kmpver =~ s/_/-/g;
    die "Kernel and KMP versions mismatch: $kver != $kmpver" if $kver ne $kmpver;

    assert_script_run("cd /usr/share/kselftests");
}

sub install_dependencies
{
    my ($collection) = @_;

    # selftests may manipulate namespaces and devices in ways that
    # trigger AVC denials on SELinux-enabled systems
    script_run('setenforce 0') if has_selinux;

    # cgroup tests do not require phub nor qa repo
    if (is_sle() && $collection ne 'cgroup') {
        add_qa_head_repo;
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    if ($collection =~ m{^net(/|$)}) {
        my $netutils_repo, my $bench_repo;
        if (is_tumbleweed()) {
            $netutils_repo = 'https://download.opensuse.org/repositories/network:/utilities/openSUSE_Factory/network:utilities.repo';
            $bench_repo = 'https://download.opensuse.org/repositories/benchmark/openSUSE_Factory/benchmark.repo';
        } elsif (is_sle('<16')) {
            $netutils_repo = 'https://download.opensuse.org/repositories/network:/utilities/15.6/network:utilities.repo';
            $bench_repo = 'https://download.opensuse.org/repositories/benchmark/15.6/benchmark.repo';
        } elsif (is_sle('=16.0')) {
            $netutils_repo = 'https://download.opensuse.org/repositories/network:/utilities/16.0/network:utilities.repo';
            $bench_repo = 'https://download.opensuse.org/repositories/benchmark/16.0/benchmark.repo';
        }
        zypper_ar($netutils_repo) if $netutils_repo;
        zypper_ar($bench_repo) if $bench_repo;

        # install build deps
        install_package('clang libcap-devel libnuma-devel libmnl-devel python3-PyYAML python3-jsonschema', trup_continue => 1);

        # install test deps
        install_available_packages('packetdrill libteam-tools wireshark iptables ipvsadm conntrack-tools jq tcpdump iperf iproute2 net-tools net-tools-deprecated ipv6toolkit netsniff-ng ndisc6 socat smcroute dropwatch');

        if (is_sle('>=16.0')) {
            # NetworkManager interferes with tests such as busy_poll_test.sh and rtnetlink.sh, due to automatically reacting to device creation
            my $netdevsim_mask = <<"EOF";
[main]
plugins=keyfile
[keyfile]
unmanaged-devices=driver:netdevsim
EOF
            write_sut_file('/etc/NetworkManager/conf.d/99-disable-netdevsim.conf', $netdevsim_mask);
            systemctl('reload NetworkManager');
        }
    }
}

sub install_kselftests
{
    my ($collection) = @_;

    install_dependencies($collection);

    if (get_var('KSELFTEST_FROM_GIT', 0)) {
        install_from_git($collection);
    } elsif (get_var('KSELFTEST_FROM_SRC', 0)) {
        build($collection);
    } else {
        install_from_repo();
    }
}

sub get_sanitized_test_name
{
    my $test = shift;
    my $test_name = $test =~ s/^[^:]+://r;    # Remove the collection from it (including sub-paths like net/forwarding), sub . with _
    my $sanitized_test_name = $test_name =~ s/\.|-/_/gr;    # Dots and hyphens should be underscore for better handling in Perl and YAML files
    return ($test_name, $sanitized_test_name);
}

sub get_whitelist
{
    my $default_whitelist_file = 'https://raw.githubusercontent.com/openSUSE/kernel-qe/refs/heads/main/kselftests_known_issues.yaml';
    if (is_sle) {
        $default_whitelist_file = 'https://qam.suse.de/known_issues/kselftests.yaml';
    }
    my $whitelist_file = get_var('KSELFTEST_KNOWN_ISSUES', $default_whitelist_file);
    my $whitelist = LTP::WhiteList->new($whitelist_file);
    return $whitelist;
}

=head2 post_process_single

 post_process_single(logfile => $logfile, collection => $collection, test => @test);

Post process a single generic selftest output file that can be written from any runner
into a single valid KTAP output for openQA with the known issues correctly tagged.

C<logfile> path to the file from the runner
C<collection> the selftest collection to parse (e.g. `bpf`, `livepatch`, `cgroup`, etc)
C<test> the subtest name to parse
C<test_index> the current index of the test
C<ktap> the initial KTAP header array

Returns the KTAP output, the number of soft and hardfails

=cut

sub post_process_single
{
    my %args = @_;
    $args{logfile} //= '$HOME/summary.tap';
    $args{test_index} //= 1;
    my $env = {
        product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
        arch => get_var('ARCH', ''),
        kernel => script_output('uname -r'),
    };
    my $whitelist = get_whitelist();

    # Avoid timeouts if the log is too big by reading it locally
    my @log;
    upload_asset($args{logfile});
    my $logfile_path = "assets_private/" . basename($args{logfile});
    open(my $logfile, '<', $logfile_path) or die("Can't open $args{logfile}");
    while (my $ln = <$logfile>) {
        push(@log, $ln);
    }
    close($logfile);
    unlink $logfile_path;

    my ($test_name, $sanitized_test_name) = get_sanitized_test_name($args{test});
    my $parser = Kselftests::parser::factory($args{collection}, $sanitized_test_name);

    my @ktap = ();
    if (defined $args{ktap}) {
        @ktap = @{$args{ktap}};
    } elsif ($log[0] !~ /^TAP version/) {
        @ktap = ("TAP version 13", "1..1", "# selftests: $args{collection}: $sanitized_test_name");
    }
    my $hardfails = 0;
    my $softfails = 0;
    for my $test_ln (@log) {
        $test_ln = $parser->parse_line($test_ln);
        if (!$test_ln) {
            next;
        }
        if ($test_ln =~ /^#?\s?not\sok\s(\d+)\s(.*?)\s*(?=#|$)/) {
            my $subtest_idx = $1;
            my $subtest_name = $2;
            my $wl_entry = $whitelist->find_whitelist_entry($env, $args{collection}, $subtest_name);
            if (defined($wl_entry) && exists($wl_entry->{skip}) && $wl_entry->{skip}) {
                $test_ln = "# ok $subtest_idx $subtest_name # SKIP";
            } elsif (defined($wl_entry)) {
                record_info("Known Issue", "'$args{test}:$subtest_name' marked as softfail");
                $test_ln = "# ok $subtest_idx $subtest_name # TODO Known Issue";
                $softfails++;
            } else {
                $hardfails++;
            }
        }
        push(@ktap, $test_ln);
    }

    if ($softfails > 0 && $hardfails == 0) {
        record_info("Known Issue", "All failed subtests in $args{test} are known issues; propagating TODO directive to the top-level");
        push(@ktap, "ok $args{test_index} selftests: $args{collection}: $sanitized_test_name # TODO Known Issue");
    }

    upload_logs("$args{logfile}", log_name => "$sanitized_test_name.tap.txt");
    return (\@ktap, $softfails, $hardfails);
}

=head2 post_process

 post_process(logfile => $logfile, collection => $collection, tests => @tests);

Post process all the Kselftests output into a single valid KTAP output file
for openQA with the known issues correctly tagged.

C<logfile> path to the summary ktap file from `run_kselftest.sh`
C<collection> the selftest collection to parse (e.g. `bpf`, `livepatch`, `cgroup`, etc)
C<tests> array of the individual subtests to parse

Returns the KTAP output, the number of soft and hard fails

=cut

sub post_process
{
    my %args = @_;
    $args{logfile} //= '$HOME/summary.tap';
    my $env = {
        product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
        arch => get_var('ARCH', ''),
        kernel => script_output('uname -r'),
    };
    my $whitelist = get_whitelist();

    my @full_ktap;
    my @summary = split(/\n/, script_output("cat $args{logfile}"));
    my $summary_ln_idx = 0;
    my $test_index = 0;
    my $softfails = 0;
    my $hardfails = 0;

    for my $test (@{$args{tests}}) {
        $test_index++;
        my ($test_name, $sanitized_test_name) = get_sanitized_test_name($test);

        # Check test result in the summary
        my $top_hardfail = 0;
        my $summary_ln;
        while ($summary_ln_idx < @summary) {
            $summary_ln = $summary[$summary_ln_idx];
            $summary_ln_idx++;
            if ($summary_ln =~ /^(not )?ok \d+ selftests: \S+: \S+/) {
                my $wl_entry = $whitelist->find_whitelist_entry($env, $args{collection}, $sanitized_test_name);
                my $test_failed = $summary_ln =~ /^not ok/ ? 1 : 0;
                if ($test_failed && defined($wl_entry) && exists($wl_entry->{skip}) && $wl_entry->{skip}) {
                    $summary_ln = "ok $test_index selftests: $args{collection}: $test_name # SKIP";
                } elsif ($test_failed && defined($wl_entry)) {
                    record_info("Known Issue", "$test marked as softfail");
                    $summary_ln = "ok $test_index selftests: $args{collection}: $test_name # TODO Known Issue";
                    $softfails++;
                } elsif ($test_failed) {
                    # The top-level test result might be rewritten later, so hold off the $hardfails increment for now
                    $top_hardfail = 1;
                }
                # Break and keep the index so that we only read each line in the summary once
                last;
            } else {
                # Push all lines that are not test results to the full log
                push(@full_ktap, $summary_ln);
            }
        }

        # Check each subtest result in the individual test log
        my ($ktap, $s, $h) = post_process_single(
            logfile => "/tmp/$test_name",
            collection => $args{collection},
            test => $test,
            test_index => $test_index,
            ktap => [],
        );
        push(@full_ktap, @{$ktap});
        $softfails += $s;
        $hardfails += $h;
        $hardfails++ if $top_hardfail && !($s > 0 && $h == 0);
        next unless $s == 0;
        push(@full_ktap, $summary_ln);
    }

    upload_logs($args{logfile}, log_name => "$args{logfile}.txt");    # Append .txt so that it can be easily previewed within openQA
    return (\@full_ktap, $softfails, $hardfails);
}

sub validate_kconfig
{
    my ($collection) = @_;
    if (script_run("test -f $collection/config") != 0) {
        return;
    }
    my $arch = script_output('uname -m');
    my @expected = split(/\n/, script_output("cat $collection/{config,config.$arch}", proceed_on_failure => 1));
    if (!@expected) {
        return;
    }
    my $kver = script_output('uname -r');
    if (script_run("test -f /boot/config-$kver") != 0) {
        record_info('KConfig', "Unable to find /boot/config-$kver file");
        return;
    }
    assert_script_run('wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/config && chmod +x config');
    my @mismatches;
    for my $expected (@expected) {
        my ($sym, $expected_st);
        if ($expected =~ /^#\s(CONFIG_[^\s]+)\s+is\s+not\s+set/) {
            $sym = $1;
            $expected_st = "undef";
        } elsif ($expected =~ /^(CONFIG_[^=\s]+)=(.+)$/) {
            $sym = $1;
            $expected_st = $2;
        } else {
            next;
        }
        my $actual_st = script_output("./config --state --file /boot/config-$kver $sym");
        if ($actual_st ne $expected_st) {
            my $mismatch = "$sym => $actual_st (actual) -> $expected_st (expected)";
            push(@mismatches, $mismatch);
        }
    }
    if (@mismatches) {
        script_output("cat <<'EOF' > config_mismatches.txt\n" . join("\n", @mismatches) . "\nEOF");
        upload_logs("config_mismatches.txt");
        record_info('Kconfig mismatches', join("\n", @mismatches));
    }
}

1;
