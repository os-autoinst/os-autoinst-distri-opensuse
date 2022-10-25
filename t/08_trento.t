use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::Exception;
use Test::MockModule;
use List::Util qw(any);
use testapi qw(set_var);
use trento;

my @calls;
my @logs;

subtest '[k8s_logs] None of the pods are for any of the required trento-server' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    # Only one PANINO pod is running in the cluster
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PANINO'; });
    # ignore them, needed by the production code but not of interest for this test
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(trento_support => sub { return; });

    # Ask for the log of trento-server-web and trento-server-runner (none of them in the list of running pods)
    k8s_logs(qw(web runner));

    note(join("\n  C-->  ", @calls));
    note(join("\n  L-->  ", @logs));
    like $calls[0], qr/.*kubectl get pods/, 'Start by getting the list of pods';
    ok scalar @calls == 1, sprintf 'Only 1 in place of %d remote commands expected as none of the running pods match with any of the requested pods', scalar @calls;
};

subtest '[k8s_logs] Get logs from running pods as it is also required' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(script_output => sub { push @calls, $_[0] if $_[0] =~ m/kubectl/; return 'trento-server-panino'; });
    $trento->redefine(upload_logs => sub { push @logs, @_; });

    # ignore them, needed by the production code but not of interest for this test
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(script_run => sub { push @calls, $_[0] if $_[0] =~ m/kubectl/; return 'PATATINE'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(trento_support => sub { return; });

    k8s_logs(qw(panino));
    note(join("\n  C-->  ", @calls));
    note(join("\n  L-->  ", @logs));
    ok scalar @calls == 3, sprintf '3 in place of %d remote commands expected: 1 to get the list of the pods, 2 to get from the required one all the logs', scalar @calls;
    ok scalar @logs == 2, '2 logs uploaded for each pod';
};

subtest '[trento_support]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, $_[0]; });
    trento_support();
    note(join("\n  C-->  ", @calls));
    note(join("\n  L-->  ", @logs));
    like $calls[0], qr/mkdir.*remote_logs/, 'Create remote_logs local folder';

    ok any { /ssh.*trento-support\.sh/ } @calls, 'Run trento-support.sh remotely';
    ok any { /scp.*\.tar\.gz.*remote_logs/ } @calls, 'scp trento-support.sh output locally';
    ok any { /ssh.*dump_scenario_from_k8\.sh/ } @calls, 'Run dump_scenario_from_k8.sh remotely';
    ok any { /scp.*\.json.*remote_logs/ } @calls, 'scp dump_scenario_from_k8.sh output locally';
};

subtest '[get_vnet] get_vnet has to call az and return a vnet' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    my $expected_net_name = 'PIZZANET';
    $trento->redefine(script_output => sub { push @calls, $_[0]; return $expected_net_name; });

    my $net_name = get_vnet(qw(GELATOGROUP));

    note(join("\n  C-->  ", @calls));
    like $calls[0], qr/az network vnet list -g GELATOGROUP --query "\[0\]\.name" -o tsv/, 'AZ command';
    is $net_name, $expected_net_name, "expected_net_name:$expected_net_name get net_name:$net_name";
};

subtest '[get_trento_deployment] with TRENTO_DEPLOY_VER' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    my $password = 'MAIONESE';
    my @recorded_passwords;
    $trento->redefine(type_password => sub { push @recorded_passwords, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    # calls to be ignored
    $trento->redefine(enter_cmd => sub { return; });
    $trento->redefine(script_run => sub { return; });

    my $gitlab_prj_id = 'MORTADELLA';
    my $gitlab_ver = 'TARTINE1.2.3';
    my $gitlab_sha = 'OLIVE';
    my $gitlag_tar = 'ARANCINO.tar.gz';

    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            # curl -s -H @gitlab_conf "https://gitlab.suse.de/api/v4/projects/qa-css%2Ftrento"
            if ($_[0] =~ /curl.*api\/v4\/projects\/qa-css.*/) { return "{\"id\":\"$gitlab_prj_id\"}"; }

            # curl -s -H @gitlab_conf https://gitlab.suse.de/api/v4/projects/7183/releases/v0.2.0
            # {"assets": {"sources": [{"format": "tar.gz", "url": "https://gitlab.suse.de/qa-css/trento/-/archive/v0.2.0/trento-v0.2.0.tar.gz"}]}}
            if ($_[0] =~ /curl.*api\/v4\/projects\/$gitlab_prj_id\/releases\/v$gitlab_ver.*jq.*assets/) { return $gitlag_tar; }
            if ($_[0] =~ /curl.*api\/v4\/projects\/$gitlab_prj_id\/releases\/v$gitlab_ver.*jq.*commit/) { return $gitlab_sha; }
            return '';
    });
    set_var('TRENTO_DEPLOY_VER', $gitlab_ver);
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', $password);
    get_trento_deployment('self', '/tmp');
    note(join("\n  -->  ", @calls));
    like $recorded_passwords[0], qr/$password/;
    ok any { /curl.*api\/v4\/projects\/$gitlab_prj_id\/repository\/.*sha=$gitlab_sha.*--output $gitlag_tar/ } @calls;
    ok any { /tar.*$gitlag_tar/ } @calls;
};

subtest '[get_trento_ip] check the az command' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'GINGERINO'; });

    my $out = get_trento_ip();
    note(join("\n  1C-->  ", @calls));
    is $out, 'GINGERINO', 'get_trento_ip output as expected';
    like $calls[0], qr/az vm show -d -g .*PASTICCINO -n .*PASTICCINO --query "publicIps" -o tsv/;
};

subtest '[cypress_configs]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(get_trento_ip => sub { return '43.43.43.43' });
    $trento->redefine(get_trento_password => sub { return 'SPUMA_DI_TONNO'; });
    my $nodes = 42;
    $trento->redefine(get_agents_number => sub { return $nodes; });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    # calls to ignore
    $trento->redefine(enter_cmd => sub { return; });

    my $ver = '9.8.7';
    set_var('TRENTO_VERSION' => $ver);
    cypress_configs('/FESTA/BANCONE/SPREMUTA');
    note(join("\n -->  ", @calls));
    note(join("\n  L-->  ", @logs));
    ok any { /cypress\.env\.py -u .*43\.43\.43\.43 -p SPUMA_DI_TONNO -f Premium -n $nodes --trento-version $ver/ } @calls;
    ok any { /cypress\.env\.json/ } @logs;
};

subtest '[get_agents_number]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    my $cloud_provider = 'POLPETTE';
    set_var('PUBLIC_CLOUD_PROVIDER' => $cloud_provider);
    set_var('QESAP_CONFIG_FILE' => 'MELANZANE_FRITTE');

    my $tmp_folder = '/FESTA';
    note("-->tmp_folder=$tmp_folder");
    set_var('QESAP_DEPLOYMENT_DIR' => $tmp_folder);

    my $inv_path = "$tmp_folder/terraform/" . lc $cloud_provider . '/inventory.yaml';
    note("-->inv_path=$inv_path");

    my $str = <<END;
all:
  children:
    hana:
      hosts:
        vmhana01:
          ansible_host: 1.2.3.4
          ansible_python_interpreter: /usr/bin/python3
        vmhana02:
          ansible_host: 1.2.3.5
          ansible_python_interpreter: /usr/bin/python3

    iscsi:
      hosts:
        vmiscsi01:
          ansible_host: 1.2.3.6
          ansible_python_interpreter: /usr/bin/python3

  hosts: null
END

    $trento->redefine(script_output => sub { push @calls, $_[0]; return $str; });

    my $res = get_agents_number();

    note(join("\n -->  ", @calls));

    is $res, 3, 'Number of agents like expected';
    like $calls[0], qr/cat $inv_path/;

};

subtest '[deploy_qesap] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @logs = ();
    $trento->redefine(qesap_execute => sub { return 0; });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    deploy_qesap();
    note(join("\n L-->  ", @logs));
    like $logs[0], qr/.*inventory\.yaml/;
};

subtest '[deploy_qesap] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return 1; });
    dies_ok { deploy_qesap() } "Expected die for internal qesap_execute returnin non zero.";
};

subtest '[destroy_qesap] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return 0; });
    destroy_qesap();
    ok 1;
};

subtest '[destroy_qesap] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return 1; });
    dies_ok { destroy_qesap() } "Expected die for internal qesap_execute returnin non zero.";
};

done_testing;
