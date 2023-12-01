MACVLANs on top of VLANs on same physical interface

- eth1 is not created or deleted by wicked on shutdown
- eth1.* vlans are created and deleted by wicked/kernel on shutdown
- macvlan* are created and deleted by wicked/kernel on shutdown (of eth1.*)

---

### tree:
```
    eth1    <-l-    eth1.11    <-l-    macvlan1
            <-l-    eth1.12    <-l-    macvlan2
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     eth1.11.11          unrequested / not required by setup interfaces
    - skip     eth1.12             unrequested / not required by setup interfaces
    - skip     eth1.12.12          unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    eth1.11           via links trigger
        - setup    eth1.11.11      via links trigger
      - setup    eth1.12           via links trigger
        - setup    eth1.12.12      via links trigger

#### wicked ifup eth1.11

    - setup    eth1.11             requested
      - setup    eth1              required lower reference
    - skip     eth1.11.11          unrequested / not required by setup interfaces
    - skip     eth1.12             unrequested / not required by setup interfaces
    - skip     eth1.12.12          unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1.11             requested
      - setup    eth1              required lower reference
      - setup    eth1.11.11        via links trigger
    - skip     eth1.12             unrequested / not required by setup interfaces
    - skip     eth1.12.12          unrequested / not required by setup interfaces

#### wicked ifup eth1.12

    - setup    eth1.12             requested
      - setup    eth1              required lower reference
    - skip     eth1.12.12          unrequested / not required by setup interfaces
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     eth1.11.11          unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1.12             requested
      - setup    eth1              required lower reference
      - setup    eth1.12.12        via links trigger
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     eth1.11.11          unrequested / not required by setup interfaces

#### wicked ifup eth1.11.11

    - setup    eth1.11.11          requested
      - setup    eth1.11           required lower reference
        - setup    eth1            required lower reference
    - skip     eth1.12             unrequested / not required by setup interfaces
    - skip     eth1.12.12          unrequested / not required by setup interfaces

#### wicked ifup eth1.12.12

    - setup    eth1.12.12          requested
      - setup    eth1.12           required lower reference
        - setup    eth1            required lower reference
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     eth1.11.11          unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
      - shutdown eth1.11           depends on lower shutdown
        - shutdown eth1.11.11      depends on lower shutdown
      - shutdown eth1.12           depends on lower shutdown
        - shutdown eth1.12.12      depends on lower shutdown

#### wicked ifdown eth1.11

    - shutdown eth1.11             requested
      - shutdown eth1.11.11        depends on lower shutdown
    - skip     eth1.12.12          unrequested / no reference to shutdown interfaces
    - skip     eth1.12             unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

#### wicked ifdown eth1.12

    - shutdown eth1.12             requested
      - shutdown eth1.12.12        depends on lower shutdown
    - skip     eth1.11.11          unrequested / no reference to shutdown interfaces
    - skip     eth1.11             unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

#### wicked ifdown eth1.11.11

    - shutdown eth1.11.11          requested
    - skip     eth1.11             unrequested / no reference to shutdown interfaces
    - skip     eth1.12.12          unrequested / no reference to shutdown interfaces
    - skip     eth1.12             unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

#### wicked ifdown eth1.12.12

    - shutdown eth1.12.12          requested
    - skip     eth1.12             unrequested / no reference to shutdown interfaces
    - skip     eth1.11.11          unrequested / no reference to shutdown interfaces
    - skip     eth1.11             unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

