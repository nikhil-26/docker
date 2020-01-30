# docker
docker private registry setup
November 30, 2018

When you dealing with production grade docker and containers you need to secure and maintain your images so to do that we need to  configure own private registry for our organisation .





Key Benefits for private docker registry :


 Private image artifactory  kind of
 Bandwidth saving during image push 
 distributed storage for 
 no need for internet connection all the time

Dokcer Private registry can be setup in two modes:

1.  Non-secure mode (http based requests)
2.  Secure mode  (https based requests)


Setup architecture :-

1.  Docker  registry   server 
  
 IP:  192.168.10.254     
 Server :  Rhel 7.5 
 firewalld  off  or   5000 port allowed 
2.   Docker client (push client)

 IP  :   192.168.10.101
  Client :   rhel 7.5 
3.  Docker client  (pull client)

 IP :    192.168.10.127
 Client :   ubuntu 16.04  

 



Use case 1:

We are going to take  Non-secure mode  registry setup

Docker  Registry  setup :

Step 1 :  checking docker version 

[root@adhoc ~]# docker version
Client:
 Version:         1.13.1
 API version:     1.26
 Package version: docker-1.13.1-68.gitdded712.el7.centos.x86_64
 Go version:      go1.9.4
 Git commit:      dded712/1.13.1
 Built:           Tue Jul 17 18:34:48 2018
 OS/Arch:         linux/amd64

Server:
 Version:         1.13.1
 API version:     1.26 (minimum version 1.12)
 Package version: docker-1.13.1-68.gitdded712.el7.centos.x86_64
 Go version:      go1.9.4
 Git commit:      dded712/1.13.1
 Built:           Tue Jul 17 18:34:48 2018
 OS/Arch:         linux/amd64
 Experimental:    false



Step  2 :     pulling  docker registry image from  docker hub

[root@adhoc ~]# docker pull registry

Step 3:   running  registry server on 5000 with restart policy

[root@adhoc ~]# docker run -itd --name privatereg  -p 5000:5000 --restart=always  docker.io/registry


[root@adhoc ~]# docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS                    NAMES
4d79520b89c4        docker.io/registry   "/entrypoint.sh /e..."   3 days ago          Up 3 days           0.0.0.0:5000->5000/tcp   registry



setup Docker  pull client  (rhel 7.5)

 Step 1 :    Installing docker

[root@station101 ~]# yum  install docker -y

step  2:   changing in configuration file 

Add these lines in the last of  /etc/sysconfig/docker  file

ADD_REGISTRY='--add-registry 192.168.10.254:5000'
INSECURE_REGISTRY='--insecure-registry 192.168.10.254:5000'


step  3:    restart  and  daemon-reload  

[root@station101 ~]# systemctl daemon-reload

[root@station101 ~]# systemctl restart  docker



step 4:   Pushing  images to docker private registry  

 Note:  first we need to tag then push it

[root@station101 ~]# docker tag  docker.io/registry  192.168.10.254:5000/registry
[root@station101 ~]# docker push 192.168.10.254:5000/registryThe push refers to a repository [192.168.10.254:5000/registry]
6b263b6e9ced: Pushed
dead8a13b621: Pushed
00a8ff67f927: Pushed
2b7bd2eefde2: Pushed
a120b7c9a693: Pushed
latest: digest: sha256:a25e4660ed5226bdb59a5e555083e08ded157b1218282840e55d25add0223390 size: 1364


Setup docker client for  Pulling  images (Ubuntu 16.04)

step 1:    install docker

[___] sudo apt  install docker

step 2 :  make changes in configuration search

-->> cat  /etc/docker/daemon.json
 
{ "insecure-registries" : ["192.168.10.254:5000"] }

Step  3 :    pulling  image from private registry  

-->> docker  pull   192.168.10.254:5000/nginx

[root@station101 ~]# systemctl daemon-reload

[root@station101 ~]# systemctl restart  docker


Important  :  setting  up secure  private private registry 


step 1:   creating  self  signed  SSL  Certificate
 root@adhoc:  openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout /certs/ca.key \
  -x509 -days 365 -out /certs/ca.crt


 Step 2:   running  docker registry  


[root@adhoc ~]# docker run -d -p 5000:5000 --restart=always --name registry -v /certs:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/ca.crt -e REGISTRY_HTTP_TLS_KEY=/certs/ca.key registry



 Setting  docker  secure client  :  

Note:     setting  registry  as same above but here we need to download  ca.crt  key to secure connection :

Step 1:  create directory  

[root@station101 ~]# mkdir -p  /etc/docker/certs.d/192.168.10.254/

step  2:   Download ca.crt  

[root@station101 ~]# scp  192.168.10.254:/certs/ca.crt  /etc/docker/certs.d/192.168.10.254


Advanced  tips and tricks:-

Important:   Right now we need to tag  the image on  docker  client for pushing and also need to mention  ip address :port  while pulling  the image .

Tip 1:      pulling  and pushing  docker image without  ip and port  

[root@station101 ~]# systemctl status docker
 ● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2018-11-30 06:25:17 GMT; 24h ago
     Docs: http://docs.docker.com
 Main PID: 1187 (dockerd-current)
    Tasks: 26
  
[root@station101 ~]# cat  /usr/lib/systemd/system/docker.service

[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target rhel-push-plugin.socket registries.service
Wants=docker-storage-setup.service
Requires=docker-cleanup.timer

[Service]
Type=notify
NotifyAccess=all
EnvironmentFile=-/run/containers/registries.conf
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
Environment=GOTRACEBACK=crash
Environment=DOCKER_HTTP_HOST_COMPAT=1
Environment=PATH=/usr/libexec/docker:/usr/bin:/usr/sbin
ExecStart=/usr/bin/dockerd-current \
          --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current \
          --default-runtime=docker-runc \
          --exec-opt native.cgroupdriver=systemd \
          --userland-proxy-path=/usr/libexec/docker/docker-proxy-current \
          --init-path=/usr/libexec/docker/docker-init-current \
          --seccomp-profile=/etc/docker/seccomp.json \
          --registry-mirror=http://192.168.10.254:5000 \       # add this
$OPTIONS \
          $DOCKER_STORAGE_OPTIONS \
          $DOCKER_NETWORK_OPTIONS \
          $ADD_REGISTRY \
          $BLOCK_REGISTRY \
          $INSECURE_REGISTRY \
      $REGISTRIES
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TimeoutStartSec=0
Restart=on-abnormal
KillMode=process

[Install]
WantedBy=multi-user.target

Restart and reload 

[root@station101 ~]# systemctl daemon-reload

[root@station101 ~]# systemctl restart  docker


Tip  2:      To  search  image in docker private registry

Search  all  present  images 

[___] curl -k -X GET https://192.168.10.254:5000/v2/_catalog
{"repositories":["busybox","centos","centos6","nginx","registry","simpleapp"]}

search tag of a particular  image:

[___] curl -k -X GET https://192.168.10.254:5000/v2/busybox/tags/list
{"name":"busybox","tags":["latest"]}
