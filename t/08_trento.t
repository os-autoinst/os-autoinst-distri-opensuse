use strict;
use warnings;
use Test::More;
use Test::Warnings;

use trento;

use Test::MockModule;
my $trento = Test::MockModule->new('trento', no_auto => 1);
my @calls;
my @logs;
$trento->redefine(script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
#$trento->redefine(get_current_job_id => sub { return 'canetto'} );
$trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
$trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
$trento->redefine(upload_logs => sub { push @logs, @_; });

subtest '[k8s_logs] None of the pods are for any of the required trento-server' => sub {
    # Only one PANINO pod is running in the cluster
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PANINO'; });

    # Ask for the log of trento-server-web and trento-server-runner (none of them in the list of running pods)
    k8s_logs(qw(web runner));

    note(join("\n  1C-->  ", @calls));
    note(join("\n  1L-->  ", @logs));
    like $calls[0], qr/.*kubectl get pods/, 'Start by getting the list of pods';
    ok scalar @calls == 1, 'Only one remote commands expected as none of the running pods match with any of the requested pods';
};

subtest '[k8s_logs] Get logs from running pods as it is also required' => sub {
    @calls = ();
    @logs = ();
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'trento-server-panino'; });
    k8s_logs(qw(panino));
    note(join("\n  2C-->  ", @calls));
    note(join("\n  2L-->  ", @logs));
    ok scalar @calls == 3, '3 remote commands expected: one to get the list of the pods, two to get from the required one all the logs';
    ok scalar @logs == 2, '2 logs uploaded for each pod';
};

subtest '[get_vnet] get_vnet has to call az and return a vnet' => sub {
    @calls = ();
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PIZZANET'; });

    my $net_name = get_vnet(qw(GELATOGROUP));

    note(join("\n  1C-->  ", @calls));
    like $calls[0], qr/az network vnet list -g GELATOGROUP --query "\[0\]\.name" -o tsv/, 'AZ command';
    ok $net_name eq 'PIZZANET', 'Directly return the script_output return string';
};


done_testing;
