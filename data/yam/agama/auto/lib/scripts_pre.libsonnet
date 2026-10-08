{
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
  disable_questions: {
    name: 'disable questions',
    content: |||
      #!/usr/bin/env bash
      agama questions mode non-interactive
    |||
  },
}
