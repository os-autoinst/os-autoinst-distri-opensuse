Bridges on physical interface and it's VLAN

---

### tree:
```
    eth1            -m-> br10
      ^
      +-l-  eth1.11 -m-> br11
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    br10              required master reference
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    br10              required master reference
      - setup      eth1.11         via links trigger
        - setup      br11          required master reference

#### wicked ifup eth1.11

    - setup    eth1.11             requested
      - setup    eth1              required lower reference
        - setup    br10            required master reference
      - setup    br11              required master reference

#### wicked ifup br10

    - setup    br10                requested
      - setup    eth1              via ports trigger
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    br10                requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

#### wicked ifup br11

    - setup    br11                requested
      - setup    eth1.11           via ports trigger
        - setup    eth1            required lower reference
          - setup    br10          required master reference

    trigger: ports=disabled

    - setup    br11                requested
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     br10                unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
      - shutdown eth1.11           depends on lower shutdown
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown eth1.11

    - shutdown eth1.11             requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown br10

    - shutdown br10                requested
      - shutdown eth1              depends on master shutdown
        - shutdown eth1.11         depends on lower shutdown
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown br11

    - shutdown br11                requested
      - shutdown eth1.11           depends on master shutdown
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces

