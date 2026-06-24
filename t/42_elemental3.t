use strict;
use warnings;
use Test::Exception;
use Test::MockModule;
use Test::More;
use Test::Warnings;
use List::Util qw(any);
use testapi;

use elemental3;

# Test elemental3_cmd function
subtest '[elemental3_cmd]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);
    my @calls;
    my %params = (
        config_dir => '/testdir',
        cmd => 'customize --type raw --output /config/image.raw',
        uri =>
          'registry.suse.de/devel/unifiedcore/main/totest/containers/beta/uc/elemental:latest',
        timeout => 120
    );

    # Check required variable
    set_var('CONTAINER_RUNTIMES', undef);
    dies_ok { elemental3_cmd(%params) } 'Fail with required variable not set';

    set_var('CONTAINER_RUNTIMES', 'podman');

    # Check with no arguments
    dies_ok { elemental3_cmd() } 'Croak if no argument is provided';

    # Simulate passing
    $elemental3->redefine(assert_script_run => sub { return 1 });
    ok(elemental3_cmd(%params), 'Pass with all args defined');

    # Check container runtime call
    $elemental3->redefine(assert_script_run => sub { push @calls, $_[0] });
    elemental3_cmd(%params);
    ok((any { /podman/ } @calls), 'podman called');
};

# Test get_container_uri function
subtest '[get_container_uri]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);

    #$elemental3->noop(qw(get_values));
    my %params = (
        url => 'https://dist.suse.de/ibs/Devel:/UnifiedCore:/Main:/ToTest',
        arch => 'aarch64',
        regex => '.my-manifest-\([0-9]*\)-\(.*\)'
    );

    # Check with no arguments
    dies_ok { get_container_uri() } 'Croak if no argument is provided';

    # Check return URI
    my $out =
      'reg.suse.de/elemental/3/main/totest/containers/my-manifest:1.2.3-4.5';
    my $value = "docker pull $out";
    $elemental3->redefine(
        get_values => sub { return ('test.file', '1.2.3', '4.5') });
    $elemental3->redefine(script_output => sub { return "$value" });
    is get_container_uri(%params), $out, 'Return URI';

    # Check empty return
    $out =
      'reg.suse.de/elemental/3/main/totest/containers/my-manifest:1.2.3-4.5';
    $value = "docker pull $out";
    $elemental3->redefine(
        get_values => sub { return ('test.file', '3.2.1', '4.5') });
    $elemental3->redefine(script_output => sub { return "$value" });
    is get_container_uri(%params), '', 'Return nothing';
};

# Test get_sysext function
subtest '[get_sysext]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);
    my @calls;
    $elemental3->noop(qw(record_info));

    # Check with no arguments
    dies_ok { get_sysext() } 'Croak if no argument is provided';

    # Simulate with variable set
    set_var('SYSEXT_IMAGES_TO_TEST', 'sysext1,sysext2,sysext3');
    $elemental3->redefine(assert_script_run => sub { push @calls, $_[0] });
    get_sysext(tmpdir => '/my-test-dir');
    ok((any { /mkdir/ } @calls), 'mkdir called');
    ok((any { /unpack-image/ } @calls), 'unpack-image called');
};

# Test get_values function
# NOTE: not easy to test this function, but if it does not work it will return
#       nothing and openQA tests will fail anyway, so issue will be seen quickly
subtest '[get_values]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);

    # Check with no arguments
    dies_ok { get_values() } 'Croak if no argument is provided';
};

done_testing;
