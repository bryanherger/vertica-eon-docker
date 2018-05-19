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

# install Minio (from minio/minio:Dockerfile.release)
# FROM alpine:3.7

COPY docker-entrypoint.sh healthcheck.sh /usr/bin/

ENV MINIO_UPDATE off
ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key

RUN \
     echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
     curl https://dl.minio.io/server/minio/release/linux-amd64/minio > /usr/bin/minio && \
     chmod +x /usr/bin/minio  && \
     chmod +x /usr/bin/docker-entrypoint.sh && \
     chmod +x /usr/bin/healthcheck.sh

EXPOSE 9000

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s \
    CMD /usr/bin/healthcheck.sh

# end Minio install

#install Vertica
ENV LANG en_US.utf8
ENV TZ "US/Eastern"

#RUN groupadd -r verticadba
#RUN useradd -r -m -g verticadba dbadmin

COPY vertica-*.rpm /tmp/

RUN yum install -y /tmp/vertica-*.rpm

# In theory, someone should make things work without ignoring the errors.
# But that's in theory, and for now, this seems sufficient.
# RUN /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 --dba-user-password-disabled --failure-threshold NONE --no-system-configuration

#USER dbadmin
# RUN /opt/vertica/bin/admintools -t create_db -s localhost --skip-fs-checks -d docker -c /home/dbadmin/docker/catalog -D /home/dbadmin/docker/data
# create Vertica Eon mode DB using MC
#RUN mkdir -p /home/dbadmin/catalog
#RUN mkdir -p /home/dbadmin/data
#USER root
#RUN chown -R dbadmin /opt/vertica/

RUN mkdir /tmp/.python-eggs
RUN chown -R dbadmin /tmp/.python-eggs
ENV PYTHON_EGG_CACHE /tmp/.python-eggs

ENV VERTICADATA /home/dbadmin/docker
VOLUME ["/home/dbadmin/docker"]

EXPOSE 5433
EXPOSE 5450

# start Minio, Vertica should be managed by MC
#CMD ["minio"]
