use strict;
use warnings;
use Test::Exception;
use Test::MockModule;
use Test::More;
use Test::Warnings;
use Mojo::Message::Response;
use Mojo::Transaction::HTTP;
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
    $elemental3->redefine('assert_script_run' => sub { return 1 });
    ok(elemental3_cmd(%params), 'Pass with all args defined');

    # Check container runtime call
    $elemental3->redefine('assert_script_run' => sub { push @calls, $_[0] });
    elemental3_cmd(%params);
    ok((any { /podman/ } @calls), 'podman called');
};

# Test get_container_uri function
subtest '[get_container_uri]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);

    my %params = (
        url => 'https://dist.suse.de/ibs/Devel:/UnifiedCore:/Main:/ToTest',
        arch => 'aarch64',
        regex => '.my-manifest-\([0-9]*\)-\(.*\)'
    );

    # Check with no arguments
    dies_ok { get_container_uri() } 'Croak if no argument is provided';

    # Mock get_values to avoid testing it again here
    $elemental3->redefine('get_values' => sub {
            return ('.my-manifest-(123)-(abc).aarch64-1.0.tar.registry.txt', '123', 'abc');
    });

    # Mock Mojo::UserAgent to simulate HTTP GET request
    my $ua_mock = Test::MockModule->new('Mojo::UserAgent');
    $ua_mock->redefine('get' => sub {
            my $res = Mojo::Message::Response->new;
            $res->code(200)->message('OK')->body("some text\npull my-registry.com/my/image:123-abc\nmore text");
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });

    my $uri = get_container_uri(%params);
    is($uri, 'my-registry.com/my/image:123-abc', 'get_container_uri returns correct URI');

    # Test failed web request
    $ua_mock->redefine('get', sub {
            my $res = Mojo::Message::Response->new;
            $res->code(404)->message('Not Found');
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });
    throws_ok { get_container_uri(%params) } qr/Cannot get '$params{url}\/.*': Not Found/, 'croaks on failed web request';

    # Test no match
    $ua_mock->redefine('get', sub {
            my $res = Mojo::Message::Response->new;
            $res->code(200)->message('OK')->body('<a href="no-match.txt">no match</a>');
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });
    throws_ok { get_container_uri(%params) } qr/Could not find any URI matching the regex/, 'croaks on no match';
};

# Test get_sysext function
subtest '[get_sysext]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);
    my @calls;
    $elemental3->noop('record_info');

    # Check with no arguments
    dies_ok { get_sysext() } 'Croak if no argument is provided';

    # Simulate with variable set
    set_var('SYSEXT_IMAGES_TO_TEST', 'sysext1,sysext2,sysext3');
    $elemental3->redefine('assert_script_run' => sub { push @calls, $_[0] });
    get_sysext(tmpdir => '/my-test-dir');
    ok((any { /mkdir/ } @calls), 'mkdir called');
    ok((any { /unpack-image/ } @calls), 'unpack-image called');
};

# Test get_values function
subtest '[get_values]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3', no_auto => 1);

    my %params = (
        url => 'https://dist.suse.de/ibs/Devel:/UnifiedCore:/Main:/ToTest',
        arch => 'aarch64',
        regex => '.*my-manifest-([0-9]*)-(.*)'
    );

    # Check with no arguments
    dies_ok { get_values() } 'Croak if no argument is provided';

    # Mock Mojo::UserAgent to simulate HTTP GET request
    my $ua_mock = Test::MockModule->new('Mojo::UserAgent');
    $ua_mock->redefine('get' => sub {
            my $res = Mojo::Message::Response->new;
            my $html_body = q{
                <a href="some-other-file.txt">some-other-file.txt</a>
                <a href="base-my-manifest-123-abc.aarch64-1.0.tar.registry.txt">base-my-manifest-123-abc.aarch64-1.0.tar.registry.txt</a>
            };
            $res->code(200)->message('OK')->body($html_body);
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });

    my ($fn, $version, $build) = get_values(%params);
    is($fn, 'base-my-manifest-123-abc.aarch64-1.0.tar.registry.txt', 'get_values returns correct filename');
    is($version, '123', 'get_values returns correct version');
    is($build, 'abc', 'get_values returns correct build');

    # Test failed web request
    $ua_mock->redefine('get', sub {
            my $res = Mojo::Message::Response->new;
            $res->code(404)->message('Not Found');
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });
    throws_ok { get_values(%params) } qr/Cannot get '$params{url}\/': Not Found/, 'croaks on failed web request';

    # Test no match
    $ua_mock->redefine('get', sub {
            my $res = Mojo::Message::Response->new;
            $res->code(200)->message('OK')->body('<a href="no-match.txt">no match</a>');
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res($res);
            return $tx;
    });
    throws_ok { get_values(%params) } qr/Could not find any file matching the regex/, 'croaks on no match';
};

# Test kubectl_cmd function
subtest '[kubectl_cmd]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine('script_retry' => sub { 0 });
    is(kubectl_cmd(cmd => 'get pods'), 0, 'kubectl_cmd: success');

    # Test failure
    my $my_cmd = 'get pods';
    $elemental3->redefine('script_retry' => sub { die "kubectl command '$my_cmd' failed!\n" });
    throws_ok { kubectl_cmd(cmd => $my_cmd) } qr/kubectl command '$my_cmd' failed!/, 'dies on failure';

    # Test missing cmd
    throws_ok { kubectl_cmd() } qr/Missing required argument <cmd>!/, 'croaks on missing cmd';
    throws_ok { kubectl_cmd(cmd => '') } qr/Missing required argument <cmd>!/, 'croaks on empty cmd';
};

# Test wait_k8s_state function
subtest '[wait_k8s_state]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine('script_retry' => sub { 0 });
    is(wait_k8s_state(regex => 'Running'), 0, 'wait_k8s_state: success');

    # Test failure
    $elemental3->redefine('script_retry' => sub { die "K8s cluster did not reach the required state\n" });
    throws_ok { wait_k8s_state(regex => 'Running') } qr/K8s cluster did not reach the required state/, 'dies on failure';

    # Test missing regex
    throws_ok { wait_k8s_state() } qr/A regex should be defined!/, 'croaks on missing regex';
    throws_ok { wait_k8s_state(regex => '') } qr/A regex should be defined!/, 'croaks on empty regex';
};

# Test wait_kubectl_cmd function
subtest '[wait_kubectl_cmd]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine('script_retry' => sub { 0 });
    is(wait_kubectl_cmd(), 0, 'wait_kubectl_cmd: success');

    # Test failure
    $elemental3->redefine('script_retry' => sub { die "kubectl command did not appear\n" });
    throws_ok { wait_kubectl_cmd() } qr/kubectl command did not appear/, 'dies on failure';
};

# Test wait_nodes_ready function
subtest '[wait_nodes_ready]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine('validate_script_output_retry' => sub { 0 });
    is(wait_nodes_ready(), 0, 'wait_nodes_ready: success');

    # Test failure
    $elemental3->redefine('validate_script_output_retry' => sub { die "K8s nodes not ready\n" });
    throws_ok { wait_nodes_ready() } qr/K8s nodes not ready/, 'dies on failure';
};

# Test wait_on_cmd function
subtest '[wait_on_cmd]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine(script_retry => sub { 0 });
    is(wait_on_cmd(cmd => 'true'), 0, 'wait_on_cmd: success');

    # Test failure
    my $my_cmd = 'not_found_cmd';
    $elemental3->redefine('script_retry' => sub { die "Command '$my_cmd' did not appear\n" });
    throws_ok { wait_on_cmd(cmd => $my_cmd) } qr/Command '$my_cmd' did not appear/, 'dies on failure';

    # Test missing cmd
    throws_ok { wait_on_cmd() } qr/Missing required argument <cmd>!/, 'croaks on missing cmd';
    throws_ok { wait_on_cmd(cmd => '') } qr/Missing required argument <cmd>!/, 'croaks on empty cmd';
};

# Test wait_script_output function
subtest '[wait_script_output]' => sub {
    my $elemental3 = Test::MockModule->new('elemental3');

    # Test success
    $elemental3->redefine(script_output_retry => sub { 'output' });
    is(wait_script_output(cmd => 'echo output'), 'output', 'wait_script_output: success');

    # Test failure
    my $my_cmd = 'not_found_cmd';
    $elemental3->redefine('script_output_retry' => sub { die "Command '$my_cmd' timed out\n" });
    throws_ok { wait_script_output(cmd => $my_cmd) } qr/Command '$my_cmd' timed out/, 'dies on failure';

    # Test missing cmd
    throws_ok { wait_script_output() } qr/Missing required argument <cmd>!/, 'croaks on missing cmd';
    throws_ok { wait_script_output(cmd => '') } qr/Missing required argument <cmd>!/, 'croaks on empty cmd';
};

done_testing;
