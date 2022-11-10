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

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));

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
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
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
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $calls[0], qr/mkdir.*remote_logs/, 'Create remote_logs local folder';

    ok((any { /ssh.*trento-support\.sh/ } @calls), 'Run trento-support.sh remotely');
    ok((any { /scp.*\.tar\.gz.*remote_logs/ } @calls), 'scp trento-support.sh output locally');
    ok((any { /ssh.*dump_scenario_from_k8\.sh/ } @calls), 'Run dump_scenario_from_k8.sh remotely');
    ok((any { /scp.*\.json.*remote_logs/ } @calls), 'scp dump_scenario_from_k8.sh output locally');
};

subtest '[get_vnet] get_vnet has to call az and return a vnet' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    my $expected_net_name = 'PIZZANET';
    $trento->redefine(script_output => sub { push @calls, $_[0]; return $expected_net_name; });

    my $net_name = get_vnet(qw(GELATOGROUP));

    note("\n  C-->  " . join("\n  C-->  ", @calls));

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
    cypress_configs('/FESTA/BANCONE/SPREMUTA');
    set_var('TRENTO_VERSION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    ok((any { /cypress\.env\.py -u .*43\.43\.43\.43 -p SPUMA_DI_TONNO -f Premium -n $nodes --trento-version $ver/ } @calls), '[cypress.env.py] cmd is ok');
    ok((any { /cypress\.env\.json/ } @logs), 'Right output json file');
};

subtest '[deploy_qesap] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @logs = ();
    $trento->redefine(qesap_execute => sub { return 0; });
    $trento->redefine(upload_logs => sub { push @logs, @_; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });

    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    deploy_qesap();
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  L-->  " . join("\n  L-->  ", @logs));
    like $logs[0], qr/PEPERONATA/;
};

subtest '[deploy_qesap] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return 1; });
    dies_ok { deploy_qesap() } "Expected die for internal qesap_execute returnin non zero.";
};

subtest '[destroy_qesap] ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();
    $trento->redefine(qesap_execute => sub { my (%args) = @_; push @calls, \%args; return 0; });
    destroy_qesap();

    ok((any { $_->{cmd} eq 'ansible' and $_->{cmd_options} eq '-d' } @calls), 'ansible cmd ok');
    ok((any { $_->{cmd} eq 'terraform' and $_->{cmd_options} eq '-d' } @calls), 'terraform cmd ok');
};

subtest '[destroy_qesap] not ok' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    $trento->redefine(qesap_execute => sub { return 1; });
    dies_ok { destroy_qesap() } "Expected die for internal qesap_execute returnin non zero.";
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

subtest '[install_agent]' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });
    $trento->redefine(get_trento_private_ip => sub { return 'FRITTI'; });

    # $wd, $playbook_location, $agent_api_key, $priv_ip
    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    install_agent('/ALICI', '/SARDINE', 'ACCIUGHE');
    set_var('PUBLIC_CLOUD_PROVIDER', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # Multiple regexp as order does no matter
    like $calls[0], qr/ansible-playbook/;
    like $calls[0], qr/.*-i \/PEPERONATA/;
    like $calls[0], qr/.*\/SARDINE\/trento-agent.yaml/;
    like $calls[0], qr/.*-e api_key=ACCIUGHE/;
    like $calls[0], qr/.*-e trento_private_addr=FRITTI -e trento_server_pub_key=.*/;
};

subtest '[install_agent] download rpm' => sub {
    my $trento = Test::MockModule->new('trento', no_auto => 1);
    @calls = ();

    $trento->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $trento->redefine(qesap_get_inventory => sub { return '/PEPERONATA'; });
    $trento->redefine(get_trento_private_ip => sub { return 'FRITTI'; });

    # $wd, $playbook_location, $agent_api_key, $priv_ip
    set_var('PUBLIC_CLOUD_PROVIDER', 'POLPETTE');
    set_var('TRENTO_AGENT_RPM', 'NACHOS');
    install_agent('/ALICI', '/SARDINE', 'ACCIUGHE');
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

done_testing;
