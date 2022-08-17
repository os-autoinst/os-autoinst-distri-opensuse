# baseimage_var is a placeholder of your base image
# use base variable when you call test_containered_app
FROM baseimage_var

RUN zypper -n in apache2 && zypper clean -a
RUN echo 'ServerName AppacheInContainer' >> /etc/apache2/httpd.conf

# set a directory for the app
WORKDIR /srv/www/htdocs/

# copy all the files to the container
COPY index.html .

# tell the port number the container should expose
EXPOSE 5000

# Set experimental variable
ENV WORLD_VAR Arda

# run the command
ENTRYPOINT ["/usr/sbin/start_apache2", "-DFOREGROUND", "-k", "start"]
