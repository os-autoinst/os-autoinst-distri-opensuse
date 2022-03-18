ARG tag
FROM $tag
ARG pkgs
ARG maint_test_repo
ENV ADDITIONAL_MODULES sle-module-legacy
COPY add_test_repositories.sh /tmp/add_test_repositories.sh
RUN chmod +x /tmp/add_test_repositories.sh
RUN /tmp/add_test_repositories.sh $maint_test_repo
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper install -y $pkgs
COPY --chown=ldap:ldap ldapserver.* slapd.conf /etc/openldap/
COPY user.ldif /tmp/user.ldif
RUN echo "root:test" | chpasswd
VOLUME ["/run"]
RUN slapadd -b dc=sssdtest,dc=com -l /tmp/user.ldif
RUN chown -R ldap:ldap /var/lib/ldap
CMD /usr/lib/openldap/start && bash 
