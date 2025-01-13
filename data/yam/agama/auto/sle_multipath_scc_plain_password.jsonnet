{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}'
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: 'nots3cr3t',
    userName: 'bernhard'
  },
  root: {
    password: 'nots3cr3t'
  },
  scripts: {
     pre: [
       {
         name: 'activate multipath',
         body: |||
           #!/bin/bash
           if ! systemctl status multpathd ; then
             echo 'Activating multipath'
             systemctl start multipathd.socket
             systemctl start multipathd
           fi
         |||
      }
    ]
  }
}
