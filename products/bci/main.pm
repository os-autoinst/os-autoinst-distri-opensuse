use strict;
use warnings;
use needle;
use File::Basename;
use scheduler 'load_yaml_schedule';

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common qw(init_main);
use main_containers;

init_main();

# Containerized YaST needs proper libyui initialization
if (load_yaml_schedule) {
    if (YuiRestClient::is_libyui_rest_api) {
        YuiRestClient::set_libyui_backend_vars;
        YuiRestClient::init_logger;
    }
    return 1;
}

main_containers::load_container_tests();

1;
