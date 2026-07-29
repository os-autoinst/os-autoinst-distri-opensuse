use strict;
use warnings;


use Test::More;
use Test::MockObject;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;

use publiccloud::zypper qw(pc_wait_quit pc_pkg_call);

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

done_testing;
