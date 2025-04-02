{
  activate_multipath: {
    name: 'activate multipath',
    content: |||
      #!/bin/bash
      if ! systemctl status multpathd ; then
        echo 'Activating multipath'
        systemctl start multipathd.socket
        systemctl start multipathd
      fi
    |||
  },
  wipe_filesystem: {
    name: 'disable questions',
    content: |||
      #!/usr/bin/env bash
      agama questions mode non-interactive
    |||
  },
}
