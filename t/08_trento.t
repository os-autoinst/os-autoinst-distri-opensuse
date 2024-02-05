use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::Exception;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any);
use testapi qw(set_var);
use trento;

my @calls;
my @logs;

subtest '[k8s_logs] None of the pods are for any of the required trento-server' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    # Only one PANINO pod is running in the cluster
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PANINO'; });
    # ignore them, needed by the production code but not of interest for this test
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Ask for the log of trento-server-web and trento-server-runner (none of them in the list of running pods)
    k8s_logs(qw(web runner));

    note("\n  C-->  " . join("\n  C-->  ", @calls));

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

    k8s_logs(qw(panino));

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    ok scalar @calls == 3, sprintf '3 in place of %d remote commands expected: 1 to get the list of the pods, 2 to get from the required one all the logs', scalar @calls;
    ok scalar @logs == 2, '2 logs uploaded for each pod';
};

subtest '[trento_support]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, $_[0]; });

    trento_support();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));

    like $calls[0], qr/mkdir.*remote_logs/, 'Create remote_logs local folder';
    ok((any { /ssh.*trento-support\.sh/ } @calls), 'Run trento-support.sh remotely');
    ok((any { /scp.*\.tar\.gz.*remote_logs/ } @calls), 'scp trento-support.sh output locally');
};

subtest '[trento_collect_scenarios]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'PATATINE'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, $_[0]; });

    trento_collect_scenarios('PANNOCHIE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));

    like $calls[0], qr/mkdir.*remote_logs/, 'Create remote_logs local folder';
    ok((any { /ssh.*dump_scenario_from_k8\.sh/ } @calls), 'Run dump_scenario_from_k8.sh remotely');
    ok((any { /scp.*PANNOCHIE\.photofinish\.tar\.gz.*remote_logs/ } @calls), 'scp dump_scenario_from_k8.sh output locally');
};

subtest '[cluster_trento_net_peering] cluster_trento_net_peering has to compose command and call 00.050 script' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    my $expected_net_name = 'PIZZANET';
    $trento->redefine(get_resource_group => sub { return 'VALLUTATA'; });
    $trento->redefine(qesap_az_get_resource_group => sub { return 'ZUPPA'; });
    $trento->redefine(qesap_az_get_vnet => sub {
            push @calls, $_[0];
            return "PIATTO_DI_VALLUTATA" if ($_[0] =~ /VALLUTATA/);
            return "PIATTO_DI_ZUPPA" if ($_[0] =~ /ZUPPA/);
    });

    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0] });

    cluster_trento_net_peering('/CROSTINI');

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    #/CROSTINI/00.050-trento_net_peering_tserver-sap_group.sh -s VALLUTATA -n PIATTO_DI_VALLUTATA -t ZUPPA -a PIATTO_DI_ZUPPA
    like $calls[2], qr/\/CROSTINI\/00\.050\-trento_net_peering_tserver-sap_group\.sh/, 'Called script in work dir';
    like $calls[2], qr/.*-s VALLUTATA/, 'Trento group';
    like $calls[2], qr/.*-n PIATTO_DI_VALLUTATA/, 'Trento net';
    like $calls[2], qr/.*-t ZUPPA/, 'Cluster group';
    like $calls[2], qr/.*-a PIATTO_DI_ZUPPA/, 'Cluster net';
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
    set_var('TRENTO_DEPLOY_VER', undef);
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    like $recorded_passwords[0], qr/$password/;
    ok((any { /curl.*api\/v4\/projects\/$gitlab_prj_id\/repository\/.*sha=$gitlab_sha.*--output $gitlag_tar/ } @calls), '[git api] cmd ok');
    ok((any { /tar.*$gitlag_tar/ } @calls), '[tar] cmd ok');
};

subtest '[get_trento_deployment] without TRENTO_DEPLOY_VER' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    my $password = 'MAIONESE';
    $trento->redefine(type_password => sub { return; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; return 'PATATINE'; });
    # calls to be ignored
    $trento->redefine(enter_cmd => sub { return; });
    $trento->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /git.*rev-parse/) { return 0; }
    });

    set_var('_SECRET_TRENTO_GITLAB_TOKEN', $password);
    get_trento_deployment('self', '/tmp');
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /git.*pull/ } @calls), '[git pull] cmd is there');
    ok((any { /git.*checkout.*master/ } @calls), '[git checkout master] cmd is there');
};

subtest '[get_trento_ip] check the az command' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'GINGERINO'; });

    my $out = get_trento_ip();
    note("\n  C-->  " . join("\n  C-->  ", @calls));

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
    $trento->redefine(qesap_get_nodes_number => sub { return $nodes; });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    # calls to ignore
    $trento->redefine(enter_cmd => sub { return; });

    my $ver = '9.8.7';
    set_var('TRENTO_VERSION' => $ver);
    set_var('PUBLIC_CLOUD_PROVIDER' => 'CACIOTTA');
    cypress_configs('/FESTA/BANCONE/SPREMUTA');
    set_var('TRENTO_VERSION', undef);
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    ok((any { /cypress\.env\.py -u .*43\.43\.43\.43 -p SPUMA_DI_TONNO -f Premium -n $nodes --trento-version $ver/ } @calls), '[cypress.env.py] cmd is ok');
    ok((any { /cypress\.env\.json/ } @logs), 'Right output json file');
};

subtest '[cluster_deploy] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @logs = ();
    $trento->redefine(qesap_execute => sub { return (0, 'log'); });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });

    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    cluster_deploy();
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $logs[0], qr/PEPERONATA/;
};

subtest '[cluster_deploy] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return (1, 'log'); });
    dies_ok { cluster_deploy() } "Expected die for internal qesap_execute returnin non zero.";
};

subtest '[cluster_destroy] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(qesap_execute => sub { my (%args) = @_; push @calls, \%args; return (0, 'log'); });
    cluster_destroy();

    ok((any { $_->{cmd} eq 'ansible' and $_->{cmd_options} eq '-d' } @calls), 'ansible cmd ok');
    ok((any { $_->{cmd} eq 'terraform' and $_->{cmd_options} eq '-d' } @calls), 'terraform cmd ok');
};

subtest '[cluster_destroy] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return (1, 'log'); });
    dies_ok { cluster_destroy() } "Expected die for internal qesap_execute returnin non zero.";
};

subtest '[deploy_vm]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(get_resource_group => sub { return 'MINESTRE'; });
    $trento->redefine(get_vm_name => sub { return 'RIBOLLITA'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    deploy_vm('/CROSTINI');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $calls[0], qr/cd \/CROSTINI/;
    like $calls[1], qr/.*trento_deploy\.py.*00_040.*MINESTRE.*RIBOLLITA.*script_00\.040\.log\.txt/;
};

subtest '[deploy_vm] TRENTO_VM_IMAGE to change image' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(get_resource_group => sub { return 'MINESTRE'; });
    $trento->redefine(get_vm_name => sub { return 'RIBOLLITA'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, @_; });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    deploy_vm('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $calls[1], qr/.*-i PARMIGIANA/;
};

subtest '[trento_acr_azure] official version' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'TOAST'; });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { push @logs, @_; });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $calls[0], qr/cd \/CROSTINI/;
    like $calls[1], qr/.*trento_acr_azure\.sh.*-r.*registry\.suse\.com\/trento\/trento-server.*script_trento_acr_azure\.log\.txt/;
    unlike $calls[1], qr/.*trento_acr_azure\.sh.*-o/;
};

subtest '[trento_acr_azure] return' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(enter_cmd => sub { });
    $trento->redefine(assert_script_run => sub { });
    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            # az acr list -g $resource_group --query \"[0].loginServer\" -o tsv
            if ($_[0] =~ /az acr list/) { return "LOGINSERVER_FRITTO"; }
            # az acr credential show -n $acr_name --query username -o tsv
            if ($_[0] =~ /az acr credential show.*username/) { return "USERNAME_LESSO"; }
            # az acr credential show -n $acr_name --query 'passwords[0].value' -o tsv
            if ($_[0] =~ /az acr credential show.*passwords/) { return "PASSWORD_ARROSTO"; }
            return 'BROCCOLI';
    });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    my %acr = trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);

    like $acr{'trento_cluster_install'}, qr/.*CROSTINI.*/;
    ok $acr{'acr_server'} eq 'LOGINSERVER_FRITTO';
    ok $acr{'acr_username'} eq 'USERNAME_LESSO';
    ok $acr{'acr_secret'} eq 'PASSWORD_ARROSTO';
};

subtest '[trento_acr_azure] custom registry for chart' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'TOAST'; });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    set_var('TRENTO_REGISTRY_CHART', 'CALDARROSTE');
    my %acr = trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    set_var('TRENTO_REGISTRY_CHART', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like $calls[1], qr/.*trento_acr_azure\.sh.*-r CALDARROSTE/;
    unlike $calls[1], qr/.*trento_acr_azure\.sh.*-o/;
};

subtest '[trento_acr_azure] custom chart version' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'TOAST'; });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    set_var('TRENTO_REGISTRY_CHART_VERSION', '12345');
    my %acr = trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    set_var('TRENTO_REGISTRY_CHART_VERSION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like $calls[1], qr/.*config_helper\.py.*-o config_images_gen\.json.*--chart registry\.suse\.com\/trento\/trento-server --chart-version 12345/;
    like $calls[2], qr/.*trento_acr_azure\.sh.*-r config_images_gen\.json.*-o/;
};

subtest '[trento_acr_azure] custom registry for web' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'TOAST'; });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    set_var('TRENTO_REGISTRY_IMAGE_WEB', 'CALDARROSTE');
    my %acr = trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    set_var('TRENTO_REGISTRY_IMAGE_WEB', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like $calls[1], qr/.*config_helper\.py.*-o config_images_gen\.json.*--web CALDARROSTE --web-version latest/;
    like $calls[2], qr/.*trento_acr_azure\.sh.*-r config_images_gen\.json.*-o/;
};

subtest '[trento_acr_azure] custom registry and version for web' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub { push @calls, $_[0]; return 'TOAST'; });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(upload_logs => sub { });

    set_var('TRENTO_VM_IMAGE', 'PARMIGIANA');
    set_var('TRENTO_REGISTRY_IMAGE_WEB', 'CALDARROSTE');
    set_var('TRENTO_REGISTRY_IMAGE_WEB_VERSION', '12345');
    my %acr = trento_acr_azure('/CROSTINI');
    set_var('TRENTO_VM_IMAGE', undef);
    set_var('TRENTO_REGISTRY_IMAGE_WEB', undef);
    set_var('TRENTO_REGISTRY_IMAGE_WEB_VERSION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like $calls[1], qr/.*config_helper\.py.*-o config_images_gen\.json.*--web CALDARROSTE --web-version 12345/;
    like $calls[2], qr/.*trento_acr_azure\.sh.*-r config_images_gen\.json.*-o/;
};

subtest '[install_trento] official version' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(upload_logs => sub { push @logs, @_; });

    my %acr;
    $acr{'trento_cluster_install'} = 'GNOCCHI';
    $acr{'acr_server'} = 'LOGINSERVER_FRITTO';
    $acr{'acr_username'} = 'USERNAME_LESSO';
    $acr{'acr_secret'} = 'PASSWORD_ARROSTO';

    install_trento(work_dir => '/CROSTINI', acr => \%acr);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));

    like $calls[0], qr/cd \/CROSTINI/;
    like $calls[1], qr/.*01\.010-trento_server_installation_premium_v\.sh.*-r LOGINSERVER_FRITTO\/trento\/trento-server -s USERNAME_LESSO -w PASSWORD_ARROSTO.*script_01\.010\.log\.txt/;
};

subtest '[install_trento] rolling release' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(get_current_job_id => sub { return 'PASTICCINO'; });
    $trento->redefine(get_trento_ip => sub { return '42.42.42.42' });
    $trento->redefine(upload_logs => sub { });

    my %acr;
    $acr{'trento_cluster_install'} = 'GNOCCHI';
    $acr{'acr_server'} = 'LOGINSERVER_FRITTO';
    $acr{'acr_username'} = 'USERNAME_LESSO';
    $acr{'acr_secret'} = 'PASSWORD_ARROSTO';

    set_var('TRENTO_REGISTRY_IMAGE_WEB', 'CALDARROSTE');
    install_trento(work_dir => '/CROSTINI', acr => \%acr);
    set_var('TRENTO_REGISTRY_IMAGE_WEB', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    like $calls[1], qr/.*-x GNOCCHI/;
};

subtest '[cluster_install_agent]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });
    $trento->redefine(get_trento_private_ip => sub { return 'FRITTI'; });

    # $wd, $playbook_location, $agent_api_key, $priv_ip
    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    cluster_install_agent('/ALICI', '/SARDINE', 'ACCIUGHE');
    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # Multiple regexp as order does no matter
    like $calls[0], qr/ansible-playbook/;
    like $calls[0], qr/.*-i \/PEPERONATA/;
    like $calls[0], qr/.*\/SARDINE\/trento-agent.yaml/;
    like $calls[0], qr/.*-e api_key=ACCIUGHE/;
    like $calls[0], qr/.*-e trento_private_addr=FRITTI -e trento_server_pub_key=.*/;
};

subtest '[cluster_install_agent] download rpm' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });
    $trento->redefine(get_trento_private_ip => sub { return 'FRITTI'; });

    # $wd, $playbook_location, $agent_api_key, $priv_ip
    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    set_var('TRENTO_AGENT_RPM', 'NACHOS');
    cluster_install_agent('/ALICI', '/SARDINE', 'ACCIUGHE');
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    set_var('TRENTO_AGENT_RPM', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # Multiple regexp as order does no matter so much
    #curl -f --verbose "https://dist.suse.de/ibs/Devel:/SAP:/trento:/factory/SLE_15_SP3/x86_64/NACHOS" --output /ALICI/NACHOS
    like $calls[0], qr/curl/;
    like $calls[0], qr/.*-f /;
    like $calls[0], qr/.*dist\.suse\.de.*\/NACHOS/;
    like $calls[0], qr/.*--output \/ALICI\/NACHOS/;
};

subtest '[trento_api_key]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            return 'GARBAGE
GARBAGE
api_key:SUPERSECRETINGREDIENT'; });
    $trento->redefine(get_trento_password => sub { return 'PIZZOCCHERI'; });
    $trento->redefine(get_trento_ip => sub { return 'BITTO'; });

    my $key = trento_api_key('/PEPERONATA');

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    like $calls[0], qr/\/PEPERONATA\/trento_deploy\/trento_deploy\.py.*api_key/;
    like $calls[0], qr/\-u admin/;
    like $calls[0], qr/\-p PIZZOCCHERI/;
    like $calls[0], qr/\-i BITTO/;
    is $key, "SUPERSECRETINGREDIENT";
};

subtest '[clone_trento_deployment] with token from worker.ini' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });

    set_var('_SECRET_TRENTO_GITLAB_TOKEN', 'TARTARA');
    clone_trento_deployment('/FRITTURA_DI_PESCE');
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    like $calls[0], qr/cd \/FRITTURA_DI_PESCE/;
    like $calls[1], qr/git.*clone.*git:TARTARA.*qa-css/;
};

subtest '[clone_trento_deployment] with custom token' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('TRENTO_GITLAB_TOKEN', 'MAIONESE');
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', 'TARTARA');
    clone_trento_deployment('/FRITTURA_DI_PESCE');
    set_var('TRENTO_GITLAB_TOKEN', undef);
    set_var('_SECRET_TRENTO_GITLAB_TOKEN', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    like $calls[0], qr/cd \/FRITTURA_DI_PESCE/;
    like $calls[1], qr/git.*clone.*git:MAIONESE.*qa-css/;
};

subtest '[az_delete_group]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(script_retry => sub { push @calls, $_[0]; });
    $trento->redefine(get_resource_group => sub { return 'MINESTRE'; });

    az_delete_group();
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like $calls[0], qr/az group delete --resource-group MINESTRE/;
};

subtest '[cypress_test_exec]' => sub {
    # Simulate cypress_test_exec for folder with single test
    # test is passing.
    # Test is focus on how many time underline functions are called
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    my $calls_cy_exec = 0;
    my $calls_cy_logs = 0;
    my $calls_parse_extra = 0;

    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            if ($_[0] =~ /iname\s".*js"/) { return "test_caciucco.js"; }
            if ($_[0] =~ /iname\s".*test_result_.*"/) { return "result_caciucco.xml"; }
            return '';
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(cypress_exec => sub { $calls_cy_exec += 1; return 0; });

    $trento->redefine(cypress_log_upload => sub { $calls_cy_logs += 1; return 0; });
    $trento->redefine(parse_extra_log => sub {
            $calls_parse_extra += 1;
            push @calls, "parse_extra_log( XUnit , $_[1] )";
            return 0; });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });

    my $ret = cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);
    note("ret : $ret");
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # ==1 as there's only one test file "test_caciucco.js"
    ok $calls_cy_exec == 1, "cypress_exec called one time.";
    # ==1 as there's only one result_caciucco.xml
    ok $calls_cy_logs == 1, "cypress_log_upload called one time.";
    ok $calls_parse_extra == 1, "parse_extra_log called one time.";
    ok $ret == 0, "Zero errors accumulated in the return.";
};

subtest '[cypress_test_exec] keep running' => sub {
    # Simulate cypress_test_exec for folder with multiple test
    # each single test is failing but function has to run all of them
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    my $calls_cy_exec = 0;
    my $calls_cy_logs = 0;
    my $calls_parse_extra = 0;

    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            if ($_[0] =~ /iname\s".*js"/) { return "test_caciucco.js\ntest_seppia.js\ntest_polpo.js"; }
            # the return here is not an error, just a simplification
            # the `find` in the production code is configured to only search
            # for result file that contain the test name.
            # Simulate here the find output that exactly only produce the only one searched file
            if ($_[0] =~ /iname\s".*test_result_.*"/) { return "result_the_right_one.xml"; }
            return '';
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # simulate an error
    $trento->redefine(cypress_exec => sub { $calls_cy_exec += 1; return 7; });

    $trento->redefine(cypress_log_upload => sub { $calls_cy_logs += 1; return 0; });
    $trento->redefine(parse_extra_log => sub {
            $calls_parse_extra += 1;
            push @calls, "parse_extra_log( XUnit , $_[1] )";
            return 0; });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });

    my $ret = cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);

    note("ret : $ret");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # ==3 as there are 3 test files
    ok $calls_cy_exec == 3, "cypress_exec called one time.";
    ok $calls_cy_logs == 3, "cypress_log_upload called one time.";
    ok $calls_parse_extra == 3, "parse_extra_log called one time.";
    ok $ret == 21, "21=7*3 errors accumulated in the return.";
};

subtest '[cypress_test_exec] Base execution' => sub {
    # test cypress_test_exec with single test file
    # this test focus on arguments passed to underline API
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(cypress_exec => sub { my (%args) = @_; push @calls, $args{cmd}; return 0; });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(parse_extra_log => sub { push @logs, @_; });
    $trento->redefine(script_output => sub {
            if ($_[0] =~ /iname\s".*js"/) { return "test_caciucco.js"; }
            if ($_[0] =~ /iname\s".*test_result_.*"/) { return "result_caciucco.xml"; }
            return '';
    });

    cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $logs[0], qr/XUnit/, "Proper parse_extra_log type";
    like $logs[1], qr/result_caciucco/, "Proper parse_extra_log file";

    ok((any { /run.*\/test_caciucco\.js.*test_result_FARINATA_test_caciucco\.xml,/ } @calls), 'Podman run of the test file');
};

subtest '[cypress_test_exec] Base execution with multiple test files' => sub {
    # test cypress_test_exec with multiple test file
    # this test focus on arguments passed to underline API
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    @logs = ();
    $trento->redefine(cypress_exec => sub { my (%args) = @_; push @calls, $args{cmd}; return 0; });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(parse_extra_log => sub { push @logs, @_; });
    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            my $find_res;
            if ($_[0] =~ /iname\s".*js"/) {
                $find_res = '
test_caciucco.js
test_capponata.js';
                note("\nfind return : $find_res");
                return $find_res; }
            if ($_[0] =~ /iname\s".*test_result_.*"/) {
                $find_res = 'result_caciucco.xml';
                note("\nfind return : $find_res");
                return $find_res;
            }
            note("\n  WARNING --> Unexpected script_output call with $_[0]");
            return '';
    });

    cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $logs[0], qr/XUnit/, "Proper parse_extra_log type";
    like $logs[1], qr/result_caciucco/, "Proper parse_extra_log file";

    ok((any { /run.*\/test_caciucco\.js/ } @calls),
        'Podman run of the test file test_caciucco.js');

    ok((any { /run.*\/test_result_FARINATA_test_caciucco\.xml/ } @calls),
        'Podman run store log in test_result_FARINATA_test_caciucco.xml');

    ok((any { /run.*\/test_capponata\.js/ } @calls),
        'Podman run of the test file test_capponata.js');

    ok((any { /run.*\/test_result_FARINATA_test_capponata\.xml/ } @calls),
        'Podman run store log in test_result_FARINATA_test_capponata.xml');
};

subtest '[cypress_test_exec] old CY' => sub {
    # This test is to check that the function compose
    # a different 'cypress run' command for two different
    # cy.io versions.
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(cypress_exec => sub { my (%args) = @_; push @calls, $args{cmd}; return 0; });
    $trento->redefine(enter_cmd => sub { });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(parse_extra_log => sub { });
    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            if ($_[0] =~ /iname\s".*js"/) { return "test_caciucco.js"; }
            if ($_[0] =~ /iname\s".*test_result_.*"/) { return "result_caciucco.xml"; }
            return '';
    });
    set_var('TRENTO_CYPRESS_VERSION', '1.2.3');
    cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);
    set_var('TRENTO_CYPRESS_VERSION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # The important part is 'cypress\/integration'
    ok((any { /run.*cypress\/integration\/FARINATA\// } @calls), 'Podman get test file in old folder');
};

subtest '[cypress_test_exec] new CY' => sub {
    # This test is to check that the function compose
    # a different 'cypress run' command for two different
    # cy.io versions.
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(cypress_exec => sub { my (%args) = @_; push @calls, $args{cmd}; return 0; });
    $trento->redefine(enter_cmd => sub { });
    $trento->redefine(wait_serial => sub { });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $trento->redefine(parse_extra_log => sub { });
    $trento->redefine(script_output => sub {
            push @calls, $_[0];
            if ($_[0] =~ /iname\s".*js"/) { return "test_caciucco.js"; }
            if ($_[0] =~ /iname\s".*test_result_.*"/) { return "result_caciucco.xml"; }
            return '';
    });
    set_var('TRENTO_CYPRESS_VERSION', '10.2.3');
    cypress_test_exec(cypress_test_dir => 'TEST_DIR', test_tag => 'FARINATA', timeout => 1000);
    set_var('TRENTO_CYPRESS_VERSION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # The important part is 'cypress\/e2e'
    ok((any { /run.*cypress\/e2e\/FARINATA\// } @calls), 'Podman get test file in new folder');
};

subtest '[cypress_exec]' => sub {
    # Simpler possible test about cypress_exec. Only test that "some"
    # podman commands are called and simulate podman_wait to return 0
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(random_string => sub { return 'STRUDEL'; });
    $trento->redefine(podman_delete_all => sub { });

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(wait_serial => sub { return; });

    # Function to async determine that podman run has finished
    $trento->redefine(podman_wait => sub { return 0; });

    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = cypress_exec(cypress_test_dir => 'TEST_DIR',
        cmd => 'FARINATA',
        log_prefix => 'FARINATA');

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    ok((any { /podman run.*FARINATA.*/ } @calls), 'Called podman run');
    ok((any { /podman.*>.*cypress_FARINATA_log.txt/ } @calls), 'podman run output redirected to file');
    ok((any { /podman.*rm.*STRUDEL/ } @calls), 'podman run output redirected to file');
    ok $ret == 0, "cypress_exec return code is ok";
};


subtest '[cypress_exec] specific Cypress version' => sub {
    # Cypress version is controlled by a setting
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(random_string => sub { return 'STRUDEL'; });
    $trento->redefine(podman_delete_all => sub { });

    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(wait_serial => sub { return; });

    # Function to async determine that podman run has finished
    $trento->redefine(podman_wait => sub { return 0; });

    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    set_var('TRENTO_CYPRESS_VERSION', '10.2.3');
    my $ret = cypress_exec(cypress_test_dir => 'TEST_DIR',
        cmd => 'FARINATA',
        log_prefix => 'FARINATA');
    set_var('TRENTO_CYPRESS_VERSION', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    ok((any { /podman run.*docker\.io\/cypress\/included:10\.2\.3/ } @calls), 'Podman run use the selected CY version tag');
};

subtest '[cypress_exec] podman run error' => sub {
    # Simulate podman run exited with error.

    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(random_string => sub { return 'STRUDEL'; });
    $trento->redefine(podman_delete_all => sub { });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(wait_serial => sub { return; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Simulate the error here
    $trento->redefine(podman_wait => sub { return 42; });

    my $ret = cypress_exec(cypress_test_dir => 'TEST_DIR',
        cmd => 'FARINATA',
        log_prefix => 'FARINATA');
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # Error has to be reported outside
    ok $ret == 42, "cypress_exec return code is ok";
};

subtest '[cluster_wait_status_by_regex] not enough arguments' => sub {
    dies_ok { cluster_wait_status_by_regex() } "Expected croak for missing arguments host.";
    dies_ok { cluster_wait_status_by_regex('hana') } "Expected croak for missing arguments regexp.";
    foreach (qw(Foo Bar)) {    # it is just to puts values in $_
                               # Intentionally try to call the function using m//
                               # to probe what happen if the user misunderstood the API
        dies_ok { cluster_wait_status_by_regex('hana', m/.*/) } "Expected croak for wrong arguments regexp.";
    }
};

subtest '[cluster_wait_status_by_regex]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(qesap_ansible_script_output => sub { push @calls, $_[0]; return 'PANINO'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    cluster_wait_status_by_regex('hana', qr/.*/);
    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(scalar @calls == 1, 'cluster_wait_status_by_regex exit after the first qesap_ansible_script_output call as the output match the regexp');
};


subtest '[cluster_wait_status_by_regex] died as no match in time' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(qesap_ansible_script_output => sub { push @calls, $_[0]; return 'CARNE'; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    dies_ok { cluster_wait_status_by_regex('hana', qr/^PESCE/) } "Never mix CARNE and PESCE";
    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
};


subtest '[cluster_wait_status]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(qesap_ansible_script_output => sub {
            push @calls, $_[0];
            return "vmhana01: AAA\n\nvmhana02: BBB";
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    cluster_wait_status('hana', sub { ((shift =~ m/AAA/) && (shift =~ m/BBB/)); });
    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(scalar @calls == 1, 'cluster_wait_status exit after the first qesap_ansible_script_output call as the output match the regexp');
};

subtest '[podman_wait] ret 0' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub {
            return 'Exited (0) 38 seconds ago,STRUDEL';
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = podman_wait(name => 'STRUDEL', timeout => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $ret == 0;
    ok((any { /wait.*pgrep.*podman/ } @calls), 'Wait podman process to terminate');
    ok((!any { /podman.*logs/ } @calls), 'podman logs not called if podman exit 0');
};

subtest '[podman_wait] support for more than one dessert' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);

    $trento->redefine(script_run => sub { });
    $trento->redefine(script_output => sub {
            return 'Exited (0) 38 seconds ago,KRAPFEN';
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = podman_wait(name => 'KRAPFEN', timeout => 42);

    ok $ret == 0;
};

subtest '[podman_wait] ret 42' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub {
            return 'Exited (42) 38 seconds ago,STRUDEL';
    });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = podman_wait(name => 'STRUDEL', timeout => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $ret == 42;
    ok((any { /podman.*logs/ } @calls), 'podman logs not called if podman exit 0');
};

subtest '[podman_wait] timeout' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(script_run => sub { push @calls, $_[0]; });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(script_output => sub {
            return 'Up 38 seconds ago,STRUDEL';
    });
    $trento->redefine(podman_exec => sub { my (%args) = @_; push @calls, $args{cmd}; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = podman_wait(name => 'STRUDEL', timeout => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $ret == 1;
    ok((any { /pkill.*cypress/ } @calls), 'pkill cypress');
    ok((any { /pkill.*podman/ } @calls), 'pkill cypress');
    ok((any { /podman.*logs/ } @calls), 'podman logs not called if podman exit 0');
};

subtest '[podman_delete_all]' => sub {
    @calls = ();
    my $trento = Test::MockModule->new('trento', no_auto => 1);

    $trento->redefine(script_output => sub {
            return 'Exited (0) 38 seconds ago,trento_cy123223
Up,trento_cy3123434
Up,somethingelsenottrento
Exited (0) 38 seconds ago,trento_cy12331345';
    });
    $trento->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $trento->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    podman_delete_all();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /podman.*rm.*trento_cy123223/ } @calls), 'Podman rm trento_cy123223');
    ok((any { /podman.*rm.*trento_cy3123434/ } @calls), 'Podman rm trento_cy3123434');
    ok((any { /podman.*rm.*trento_cy12331345/ } @calls), 'Podman rm trento_cy12331345');
    ok(scalar @calls == 3, 'somethingelsenottrento is not removed');
};

done_testing;
