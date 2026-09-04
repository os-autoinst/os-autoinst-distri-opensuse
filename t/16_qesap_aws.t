use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use Data::Dumper;

use testapi 'set_var';
use sles4sap::qesap::aws;

subtest '[qesap_aws_create_credentials] missing arguments' => sub {
    dies_ok { qesap_aws_create_credentials(secret => 'ROSAZZO', conf_trgt => 'VERNACCIA.YAML') } 'Die for missing argument key';
    dies_ok { qesap_aws_create_credentials(key => 'RAMANDOLO', conf_trgt => 'VERNACCIA.YAML') } 'Die for missing argument secret';
    dies_ok { qesap_aws_create_credentials(key => 'RAMANDOLO', secret => 'ROSAZZO') } 'Die for missing argument conf_trgt';
};

subtest '[qesap_aws_create_credentials]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    my @contents;

    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'SANGIOVESE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });

    qesap_aws_create_credentials(key => 'RAMANDOLO', secret => 'ROSAZZO', conf_trgt => 'VERNACCIA.YAML');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    ok((any { /awk.*aws_credentials.*VERNACCIA\.YAML/ } @calls), 'credentials file path resolved from conf_trgt');
    ok((any { m{mkdir -p ~/\.aws} } @calls), '.aws directory initialized');
    ok((any { m{curl http://10\.0\.2\.2/tests/+files/credentials -o SANGIOVESE} } @calls), 'AWS credentials file downloaded to resolved path');
    ok((any { m{cp SANGIOVESE ~/\.aws/credentials} } @calls), 'credentials copied into ~/.aws/credentials');
    is $contents[0], 'credentials', "AWS credentials file: credentials is the expected value and got $contents[0]";
    like $contents[1], qr/aws_access_key_id = RAMANDOLO/, 'aws_access_key_id carries the provided key';
    like $contents[1], qr/aws_secret_access_key = ROSAZZO/, 'aws_secret_access_key carries the provided secret';
};

subtest '[qesap_aws_create_config] missing arguments' => sub {
    dies_ok { qesap_aws_create_config() } 'Die for missing argument region';
};

subtest '[qesap_aws_create_config]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);

    my @calls;
    my @contents;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'GATTINARA' });

    qesap_aws_create_config(region => 'GRECODITUFO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    ok((any { m{mkdir -p ~/\.aws} } @calls), 'Create a folder in HOME for the AWS config files');
    ok((any { m{curl GATTINARA/files/config -o ~/\.aws/config} } @calls), 'Place the aws config file in the right place');
    is $contents[0], 'config', 'config is the tmp file name';
    like $contents[1], qr/region = GRECODITUFO/, 'region value ends up in the config file';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment] missing arguments' => sub {
    dies_ok { qesap_aws_delete_transit_gateway_vpc_attachment() } 'Die for missing argument id';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub {
            push @calls, $_[0];
            return '[{"TransitGatewayAttachmentId": "PROSECCO", "State": "deleted"}]'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(id => 'CONERO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 delete-transit-gateway-vpc-attachment.*--transit-gateway-attachment-id CONERO/ } @calls), 'delete command targets the given id');
    ok $res, 'Delete of transit gateway vpc attachment is fine.';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment] no wait' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            push @calls, 'qesap_aws_get_transit_gateway_vpc_attachment';
            return [];
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(id => 'CONERO', wait => 0);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res, 'Delete returns true immediately when wait is 0';
    ok((none { /qesap_aws_get_transit_gateway_vpc_attachment/ } @calls), 'No polling for state when wait is 0');
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment] timeout' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub {
            push @calls, $_[0];
            return '[{"TransitGatewayAttachmentId": "PROSECCO", "State": "deleting"}]'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(id => 'CONERO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Delete of transit gateway vpc attachment timeout.';
};

subtest '[qesap_aws_filter_query] missing arguments' => sub {
    dies_ok { sles4sap::qesap::aws::qesap_aws_filter_query(filter => 'F', query => 'Q') } 'Die for missing argument cmd';
    dies_ok { sles4sap::qesap::aws::qesap_aws_filter_query(cmd => 'C', query => 'Q') } 'Die for missing argument filter';
    dies_ok { sles4sap::qesap::aws::qesap_aws_filter_query(cmd => 'C', filter => 'F') } 'Die for missing argument query';
};

subtest '[qesap_aws_filter_query]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'MONTEPULCIANO'; });

    my $res = sles4sap::qesap::aws::qesap_aws_filter_query(cmd => 'describe-vpcs', filter => 'Name=tag,Values=DOLCETTO', query => 'Vpcs[]');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $res, 'MONTEPULCIANO', 'Return the raw script_output';
    ok((any { /aws ec2 describe-vpcs/ } @calls), 'aws ec2 <cmd> is composed');
    ok((any { /--filters Name=tag,Values=DOLCETTO/ } @calls), 'filter is passed through');
    ok((any { /--query Vpcs\[\]/ } @calls), 'query is passed through');
    ok((any { /--output text/ } @calls), 'default output format is text');
};

subtest '[qesap_aws_filter_query] with json output' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return '[]'; });

    sles4sap::qesap::aws::qesap_aws_filter_query(cmd => 'describe-vpcs', filter => 'Name=tag,Values=DOLCETTO', query => 'Vpcs[]', output => 'json');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /--output json/ } @calls), 'output json overrides the default text format');
};

subtest '[qesap_aws_get_mirror_tg] missing arguments' => sub {
    dies_ok { sles4sap::qesap::aws::qesap_aws_get_mirror_tg() } 'Die for missing argument mirror_tag';
};

subtest '[qesap_aws_get_mirror_tg]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_filter_query => sub { my (%args) = @_; push @calls, $args{filter}; return 'tgw-VERMENTINO'; });

    my $res = sles4sap::qesap::aws::qesap_aws_get_mirror_tg(mirror_tag => 'PIGATO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $res, 'tgw-VERMENTINO', 'Return the transit gateway id from filter_query';
    ok((any { /Name=tag-key,Values=Project/ } @calls), 'filter by Project tag key');
    ok((any { /Name=tag-value,Values=PIGATO/ } @calls), 'mirror_tag is used as tag-value filter');
};

subtest '[qesap_aws_get_tgw_attachments] no mirror_tag' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = qesap_aws_get_tgw_attachments();

    is_deeply $res, [], 'Return empty list when mirror_tag is not provided';
};

subtest '[qesap_aws_get_tgw_attachments] no transit gateway found' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_mirror_tg => sub { return ''; });

    my $res = qesap_aws_get_tgw_attachments(mirror_tag => 'PIGATO');

    is_deeply $res, [], 'Return empty list when no transit gateway id is found';
};

subtest '[qesap_aws_get_tgw_attachments]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_mirror_tg => sub { return 'tgw-VERMENTINO'; });
    $qesap->redefine(qesap_aws_filter_query => sub {
            my (%args) = @_;
            push @calls, $args{filter};
            return '[{"Id":"tgw-attach-FIANO","Name":"FIANO-tgw-attach"}]';
    });

    my $res = qesap_aws_get_tgw_attachments(mirror_tag => 'PIGATO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /Name=transit-gateway-id,Values=tgw-VERMENTINO/ } @calls), 'filter attachments by the resolved transit gateway id');
    ok((any { /Name=state,Values=available/ } @calls), 'only available attachments are requested');
    is $res->[0]{Id}, 'tgw-attach-FIANO', 'decoded attachment id is returned';
    is $res->[0]{Name}, 'FIANO-tgw-attach', 'decoded attachment name is returned';
};

done_testing;
