# PLEASE READ THE LICENSE FILE.  THERE IS NO SUPPORT OR MAINTENANCE FOR THIS PROJECT.
FROM centos:centos7
MAINTAINER Bryan Herger <bryanherger@gmail.com>

# configure Linux image: CentOS latest
# Update the image
RUN yum update -y; yum clean all

# Install Dependencies
RUN yum install -y openssl which mcelog gdb sysstat sudo net-tools iproute nano
RUN yum install -y openssh-server openssh-clients

# grab gosu for easy step-down from root
RUN yum install -y curl \
	&& curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' \
	&& chmod +x /usr/local/bin/gosu

RUN yum clean all

# set the root password so we can ssh in
RUN echo changeme | passwd --stdin root

#install Vertica
ENV LANG en_US.utf8
ENV TZ "US/Eastern"

#RUN groupadd -r verticadba
#RUN useradd -r -m -g verticadba dbadmin

ADD packages/vertica-9.1.0-1.x86_64.RHEL6.rpm /tmp/

RUN yum install -y /tmp/vertica-9.1.0-1.x86_64.RHEL6.rpm

# copy in the patched Python file. Must match version above!
COPY bootstrap_catalog.py /opt/vertica/share/eggs/vertica/engine/api/
COPY load_remote_catalog.py /opt/vertica/share/eggs/vertica/engine/api/
COPY vertica_download_file.py /opt/vertica/share/eggs/vertica/engine/api/

# In theory, someone should make things work without ignoring the errors.
# But that's in theory, and for now, this seems sufficient.
# RUN /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 --dba-user-password-disabled --failure-threshold NONE --no-system-configuration

#USER dbadmin
# RUN /opt/vertica/bin/admintools -t create_db -s localhost --skip-fs-checks -d docker -c /home/dbadmin/docker/catalog -D /home/dbadmin/docker/data
# create Vertica Eon mode DB using MC
#RUN mkdir -p /home/dbadmin/catalog
#RUN mkdir -p /home/dbadmin/data

# ENV VERTICADATA /home/dbadmin/docker
# VOLUME ["/home/dbadmin/docker"]

# add SSHD host keys
ADD etc.ssh/* /etc/ssh/
RUN chmod 600 /etc/ssh/*key*

# add SSH passwordless keys
ADD root.ssh/* /root/.ssh/
RUN chmod -R 700 /root/.ssh/
RUN chmod 600 /root/.ssh/*

# allow inbound SSH and Vertica sockets
EXPOSE 22
EXPOSE 5433
EXPOSE 5450

#RUN /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 --dba-user-password-disabled --failure-threshold NONE --no-system-configuration
#RUN chown -R dbadmin /opt/v*
# create Vertica Eon mode DB using MC

# I have a fake AWS metadata endpoint here...
#ENV PG_TEST_METADATA_URL=http://192.168.1.242/latest/meta-data/

# start Minio, Vertica should be managed by MC

# set AWS keys in env
ENV AWS_ACCESS_KEY_ID="W64OSJPD8BMOJ91XCR38"
ENV AWS_SECRET_ACCESS_KEY="d+nO8Y+W7cEkqtXWnTcO07GWdhpUhd62D0nRtu0k"

ADD create-cluster.sh /tmp/
ADD join-cluster.sh /tmp/
ADD leave-cluster.sh /tmp/
ADD create-start-db.sh /tmp/

# use sshd as the interactive process
# CMD ["/usr/sbin/sshd -D"]

