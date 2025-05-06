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
    name: 'wipefs',
    content: |||
      #!/usr/bin/env bash
      for i in `lsblk -n -l -o NAME -d -e 7,11,254`
          do wipefs -af /dev/$i
          sleep 1
          sync
      done
    |||
  },
  ibft_answers: {
    name: 'ibft test answers',
    content: |||
      #!/usr/bin/env bash
      agama questions mode non-interactive
      cat > /tmp/ibft_answers.json <<EOF
      {
        "answers": [
         {
           "class":"storage.commit_error",
           "answer": "yes"
         },
         {
           "class": "storage.luks_activation",
           "answer": "skip"
         }
        ]
      }
      EOF
      agama questions list
      agama questions answers /tmp/ibft_answers.json
      agama questions list
    |||
  },
}
