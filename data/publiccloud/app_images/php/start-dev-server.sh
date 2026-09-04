#!/bin/bash
set -euo pipefail

php -r 'echo readfile("/srv/www/htdocs/hello-suse/index.php");' | grep "Hello SUSE"

sudo touch /var/log/php-server.log
sudo chmod 777 /var/log/php-server.log
nohup php -S 0.0.0.0:8000 -t /srv/www/htdocs/hello-suse > /var/log/php-server.log 2>&1 </dev/null &

exit 0