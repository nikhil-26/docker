FROM centos
MAINTAINER nikhil sharma
RUN yum install httpd -y
EXPOSE 80
ENTRYPOINT httpd -DFOREGROUND
