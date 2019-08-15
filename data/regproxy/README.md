Proxy for rewriting Docker and OCI Registry APIv2 requests
----------------------------------------------------------

This python script is used to redirect pulls from the registry to pick images
from a different location (totest, staging, ...) if necessary.

Hardcoded SSL certificates
--------------------------

To support multi-machine tests easily, the self-signed cert is part of this
directory. To regenerate it, run this:

openssl req -x509 -newkey rsa:2048 -keyout regproxy-key.pem -out regproxy-cert.pem -days 730 -nodes -batch -subj '/CN=registry.opensuse.org/O=Kinda openSUSE/C=DE'
