use strict;
use warnings;
use Test::More;
use Test::Warnings;
use List::Util qw(any);

use testapi qw(set_var);

use trento;

use Test::MockModule;
my $trento = Test::MockModule->new('trento', no_auto => 1);
my @calls;
my @logs;
$trento->redefine(script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
$trento->redefine(enter_cmd => sub { push @calls, $_[0]; return 'PATATINE'; });
$trento->redefine(type_password => sub { push @calls, $_[0]; return 'PATATINE'; });

$trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
$trento->redefine(upload_logs => sub { push @logs, @_; });

subtest '[k8s_logs] None of the pods are for any of the required trento-server' => sub {
    # Only one PANINO pod is running in the cluster
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PANINO'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });

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
    my $expected_net_name = 'PIZZANET';
    $trento->redefine(script_output => sub { push @calls, $_[0]; return $expected_net_name; });

    my $net_name = get_vnet(qw(GELATOGROUP));

    note(join("\n  1C-->  ", @calls));
    like $calls[0], qr/az network vnet list -g GELATOGROUP --query "\[0\]\.name" -o tsv/, 'AZ command';
    ok $net_name eq $expected_net_name, 'expected_net_name:' . $expected_net_name . ' but get net_name:' . $net_name;
};

subtest '[get_trento_deployment] with TRENTO_DEPLOY_VER' => sub {
    @calls = ();

    my $password = 'MAIONESE';
    my @recorded_passwords;
    $trento->redefine(type_password => sub { push @recorded_passwords, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; return 'PATATINE'; });

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
    note(join("\n  1C-->  ", @calls));
    like $recorded_passwords[0], qr/$password/;
    ok any { /curl.*api\/v4\/projects\/$gitlab_prj_id\/repository\/.*sha=$gitlab_sha.*--output $gitlag_tar/ } @calls;
    ok any { /tar.*$gitlag_tar/ } @calls;
};

subtest '[get_trento_ip] check the az command' => sub {
    @calls = ();
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'GINGERINO'; });

    my $out = get_trento_ip();
    note(join("\n  1C-->  ", @calls));
    is $out, 'GINGERINO', 'get_trento_ip output as expected';
    like $calls[0], qr/az vm show -d -g .*PASTICCINO -n .*PASTICCINO --query "publicIps" -o tsv/;
};

subtest '[cypress_configs]' => sub {
    @calls = ();
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(get_trento_ip => sub { return '43.43.43.43' });
    $trento->redefine(get_trento_password => sub { return 'SPUMA_DI_TONNO'; });
    my $nodes = 42;
    $trento->redefine(get_agents_number => sub { return $nodes; });

    my $ver = '9.8.7';
    set_var('TRENTO_VERSION' => $ver);
    cypress_configs('/FESTA/BANCONE/SPREMUTA');
    note(join("\n -->  ", @calls));
    ok any { /cypress\.env\.py -u .*43\.43\.43\.43 -p SPUMA_DI_TONNO -f Premium -n $nodes --trento-version $ver/ } @calls;
};

subtest '[get_agents_number]' => sub {
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

done_testing;
