#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: minsampler init [-hv] [-n network] [-r freebsd_version] sampler_name

    network defaults to '10.100.1' - do not change as things break
    freebd_version defaults to '13.1'
"
}

if [ -f config.ini ]; then
    # shellcheck disable=SC1091
    source config.ini
else
    echo "config.ini is missing? Please fix"
    exit 1; exit 1
fi

if [ -z "${ACCESSIP}" ]; then
    echo "ACCESSIP is unset. Please configure web access IP in config.ini"
    exit 1; exit 1
fi

if [ -z "${DISKSIZE}" ]; then
    echo "DISKSIZE is unset. Please configure disk sizes in config.ini"
    exit 1; exit 1
fi

availablespace=$(df "${PWD}" | awk '/[0-9]%/{print $(NF-2)}')
totaldisksize=$(echo "8 * ${DISKSIZE}" |bc -l)

if [ "${totaldisksize}" -ge "${availablespace}" ]; then
    echo "Insufficient disk space for virtual disks of size ${DISKSIZE}. Please reduce the disk size in config.ini or free up some disk space"
    exit 1; exit 1
fi

# Current FreeBSD version
FREEBSD_VERSION=13.1

# Do not change this if using Virtualbox DHCP on primary interface
GATEWAY="10.0.2.2"

# enable experimental disk support
export VAGRANT_EXPERIMENTAL="disks"

OPTIND=1
while getopts "hv:n:r:" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  v)
    # shellcheck disable=SC2034
    VERBOSE="YES"
    ;;
  n)
    NETWORK="${OPTARG}"
    ;;
  r)
    FREEBSD_VERSION="${OPTARG}"
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

shift "$((OPTIND-1))"

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

NETWORK="$(echo "${NETWORK:=10.100.1}" | awk -F\. '{ print $1"."$2"."$3 }')"
SAMPLER_NAME="$1"

set -eE
trap 'echo error: $STEP failed' ERR
# shellcheck disable=SC1091
source "${INCLUDE_DIR}/common.sh"
common_init_vars

set -eE
trap 'echo error: $STEP failed' ERR

if [ -z "${SAMPLER_NAME}" ] || [ -z "${FREEBSD_VERSION}" ]; then
  usage
  exit 1
fi

if [[ ! "${SAMPLER_NAME}" =~ $SAMPLER_NAME_REGEX ]]; then
  >&2 echo "invalid sampler name $SAMPLER_NAME"
  exit 1
fi

if [[ ! "${FREEBSD_VERSION}" =~ $FREEBSD_VERSION_REGEX ]]; then
  >&2 echo "unsupported freebsd version $FREEBSD_VERSION"
  exit 1
fi

if [[ ! "${NETWORK}" =~ $NETWORK_REGEX ]]; then
  >&2 echo "invalid network $NETWORK (expecting A.B.C, e.g. 10.100.1)"
  exit 1
fi

step "Init sampler"
mkdir "$SAMPLER_NAME"
git init "$SAMPLER_NAME" >/dev/null
cd "$SAMPLER_NAME"
if [ "$(git branch --show-current)" = "master" ]; then
  git branch -m master main
fi

step "Generate SSH key to upload"
ssh-keygen -b 2048 -t rsa -f miniokey -q -N ""

# temp fix
step "Make _build directory as a temporary fix for error which crops up"
mkdir -p _build/

# fix for SSH timeouts
export SSH_AUTH_SOCK=""

# add remote IP to file for ansible read
echo "${ACCESSIP}" > access.ip

# Create ansible site.yml to process once hosts are up
cat >site.yml<<"EOF"
---

- hosts: all
  tasks:
  - name: Build facts from stored UUID values
    set_fact:
      minio_access_ip: "{{ lookup('file', 'access.ip') }}"
      minio1_hostname: minio1
      minio2_hostname: minio2
      minio_resource: sampler
      minio_dataset: mydata
      minio_nat_gateway: 10.100.1.1
      minio1_ip_address: 10.100.1.3
      minio2_ip_address: 10.100.1.4
      local_minio_disk1: /mnt/minio/disk1
      local_minio_disk2: /mnt/minio/disk2
      local_minio_disk3: /mnt/minio/disk3
      local_minio_disk4: /mnt/minio/disk4
      minio1_disk1: https://10.100.1.3:9000/mnt/minio/disk1
      minio1_disk2: https://10.100.1.3:9000/mnt/minio/disk2
      minio1_disk3: https://10.100.1.3:9000/mnt/minio/disk3
      minio1_disk4: https://10.100.1.3:9000/mnt/minio/disk4
      minio2_disk1: https://10.100.1.4:9000/mnt/minio/disk1
      minio2_disk2: https://10.100.1.4:9000/mnt/minio/disk2
      minio2_disk3: https://10.100.1.4:9000/mnt/minio/disk3
      minio2_disk4: https://10.100.1.4:9000/mnt/minio/disk4
      minio_erasure_coding_collection: https://minio{1...2}:9000/mnt/minio/disk{1...4}
      minio_access_key: sampler
      minio_access_password: samplerpasswordislong
      minio_nameserver: 8.8.8.8
      minio1_nomad_client_ip: 10.100.1.3
      minio2_nomad_client_ip: 10.100.1.4
      minio_ssh_key: "~/.ssh/miniokey"
      minio1_ssh_port: 12222
      minio2_ssh_port: 12223
      local_openssl_dir: /usr/local/etc/ssl
      local_openssl_ca_dir: /usr/local/etc/ssl/CAs
      local_openssl_conf: openssl.conf
      local_openssl_root_key: rootca.key
      local_openssl_root_cert: rootca.crt
      local_openssl_private_key: private.key
      local_openssl_public_cert: public.crt
      local_openssl_root_key_size: 8192
      local_openssl_root_key_expiry: 3650
      local_openssl_client_key_size: 4096
      local_openssl_client_key_expiry: 3650
      local_openssl_nginx_cert: bundle.pem
      datacenter_name: samplerdc
      gossip_key: "BBtPyNSRI+/iP8RHB514CZ5By3x1jJLu4SqTVzM4gPA="
      jails_interface: jailnet
      consul_base: consul-amd64-13_1
      consul_version: "2.0.27"
      consul_pot_name: consul-amd64-13_1_2_0_27
      consul_clone_name: consul-clone
      consul_url: https://potluck.honeyguide.net/consul
      consul_ip: 10.200.1.2
      consul_nodename: consul
      consul_bootstrap: 1
      consul_peers: 1.2.3.4
      nomad_base: nomad-server-amd64-13_1
      nomad_version: "2.0.21"
      nomad_pot_name: nomad-server-amd64-13_1_2_0_21
      nomad_clone_name: nomad-server-clone
      nomad_ip: 10.200.1.3
      nomad_nodename: nomad
      nomad_url: https://potluck.honeyguide.net/nomad-server
      nomad_bootstrap: 1
      nomad_importjobs: 1
      nomad_job_src: /root/nomadjobs/nextcloud.nomad
      nomad_job_dest: /root/nomadjobs/nextcloud.nomad
      traefik_base: traefik-consul-amd64-13_1
      traefik_version: "1.3.5"
      traefik_pot_name: traefik-consul-amd64-13_1_1_3_5
      traefik_clone_name: traefik-consul-clone
      traefik_url: https://potluck.honeyguide.net/traefik-consul
      traefik_ip: 10.200.1.4
      traefik_mount_in: /mnt/data/jaildata/traefik
      traefik_nodename: traefikconsul
      beast_base: beast-of-argh-amd64-13_1
      beast_version: "0.0.29"
      beast_pot_name: beast-of-argh-amd64-13_1_0_0_29
      beast_nodename: beast
      beast_url: https://potluck.honeyguide.net/beast-of-argh/
      beast_clone_name: beast-clone
      beast_ip: 10.200.1.99
      beast_mount_in: /mnt/data/jaildata/beast
      beast_mount_dest: /mnt
      beast_join_consul: "10.200.1.2"
      beast_grafana_user: admin
      beast_grafana_pass: sampler
      beast_scrape_consul: "10.200.1.2:8500"
      beast_scrape_nomad: "10.200.1.3:4646"
      beast_scrape_db: "10.200.1.15"
      beast_scrape_traefik: "10.200.1.4:8082"
      beast_influxsource: "10.200.1.100"
      beast_influxname: database
      beast_smtphostport: "localhost:25"
      beast_smtp_user: "your@example.com"
      beast_smtp_pass: "examplepass"
      beast_smtp_from: "sampler@minio-sampler.com"
      beast_alertaddress: "your@example.com"
      beast_syslog_version: "3.37"
      beast_empty_var: ""
      mariadb_base: mariadb-amd64-13_1
      mariadb_version: "2.0.12"
      mariadb_pot_name: mariadb-amd64-13_1_2_0_12
      mariadb_url: https://potluck.honeyguide.net/mariadb
      mariadb_nodename: mariadb
      mariadb_clone_name: mariadb-clone
      mariadb_ip: 10.200.1.15
      mariadb_mount_in: /mnt/data/jaildata/mariadb/var_db_mysql
      mariadb_mount_dest: /var/db/mysql
      mariadb_dumpuser: root
      mariadb_rootpass: sampler
      mariadb_scrapepass: sampler
      mariadb_dumpfile: /var/db/mysql/full_mariadb_backup.sql
      mariadb_dumpschedule: "5 21 * * *"
      mariadb_nc_db_name: nextcloud
      mariadb_nc_user: nextcloud
      mariadb_nc_pass: mynextcloud1345swdwfr3t34rw
      mariadb_nc_proxy_port: "3306"
      nextcloud_minio: "10.100.1.3:9000"
      nextcloud_minio_alt: "10.100.1.1:10901"
      nextcloud_url: https://potluck.honeyguide.net/nextcloud-nginx-nomad
      nextcloud_base: nextcloud-nginx-nomad-amd64-13_1
      nextcloud_version: "0.67"
      nextcloud_copy_objectstore_src: /root/nomadjobs/objectstore.config.php
      nextcloud_copy_objectstore_dest: /root/objectstore.config.php
      nextcloud_copy_mysql_src: /root/nomadjobs/mysql.config.php
      nextcloud_copy_mysql_dest: /root/mysql.config.php
      nextcloud_copy_custom_src: /root/nomadjobs/custom.config.php
      nextcloud_copy_custom_dest: /root/custom.config.php
      nextcloud_www_src: /mnt/data/jaildata/nextcloud/nextcloud_www
      nextcloud_www_dest: /usr/local/www/nextcloud
      nextcloud_storage_src: /mnt/data/jaildata/nextcloud/storage
      nextcloud_storage_dest: /mnt/nextcloud
      nextcloud_rootca_src: /usr/local/etc/ssl/CAs/rootca.crt
      nextcloud_rootca_dest: /root/rootca.crt
      nextcloud_admin_user: sampler
      nextcloud_admin_pass: sampler123
      nextcloud_admin_email: "sampler@example.com"
      nextcloud_custom_version: '25.0.1.1'

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Enable root ssh logins and set keep alives
    become: yes
    become_user: root
    shell:
      cmd: |
        sed -i '' \
          -e 's|^#PermitRootLogin no|PermitRootLogin yes|g' \
          -e 's|^#Compression delayed|Compression no|g' \
          -e 's|^#ClientAliveInterval 0|ClientAliveInterval 20|g' \
          -e 's|^#ClientAliveCountMax 3|ClientAliveCountMax 5|g' \
          /etc/ssh/sshd_config

  - name: Restart sshd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: sshd
      state: restarted

  - name: Wait for port 22 to become open, wait for 5 seconds
    wait_for:
      port: 22
      delay: 5

  - name: Add minio hosts to /etc/hosts
    become: yes
    become_user: root
    shell:
      cmd: |
        cat <<EOH >> /etc/hosts
        {{ minio1_ip_address }} {{ minio1_hostname }}
        {{ minio2_ip_address }} {{ minio2_hostname }}
        EOH

  - name: Add dns to resolv.conf
    become: yes
    become_user: root
    copy:
      dest: /etc/resolv.conf
      content: |
        nameserver {{ minio_nameserver }}
        nameserver 10.0.2.3

  - name: Create pkg config directory
    become: yes
    become_user: root
    file: path=/usr/local/etc/pkg/repos state=directory mode=0755

  - name: Create pkg config
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/pkg/repos/FreeBSD.conf
      content: |
        FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }

  - name: Upgrade package pkg
    become: yes
    become_user: root
    shell:
      cmd: "pkg upgrade -qy pkg"

  - name: Force package update
    become: yes
    become_user: root
    shell:
      cmd: "pkg update -fq"

  - name: Upgrade packages
    become: yes
    become_user: root
    shell:
      cmd: "pkg upgrade -qy"

  - name: Install common packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - bash
        - curl
        - nano
        - vim-tiny
        - sudo
        - python39
        - rsync
        - tmux
        - jq
        - dmidecode
        - openntpd
        - pftop
        - openssl
        - nginx-full
        - minio
        - minio-client
        - py39-minio
        - nmap
        - syslog-ng
      state: present

  - name: Enable openntpd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: openntpd
      enabled: yes

  - name: Start openntpd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: openntpd
      state: started

  - name: Disable coredumps
    become: yes
    become_user: root
    sysctl:
      name: kern.coredump
      value: '0'

  - name: Create .ssh directory
    ansible.builtin.file:
      path: /home/vagrant/.ssh
      state: directory
      mode: '0700'
      owner: vagrant
      group: vagrant

  - name: Create root .ssh directory
    ansible.builtin.file:
      path: /root/.ssh
      state: directory
      mode: '0700'
      owner: root
      group: wheel

  - name: copy over ssh private key
    ansible.builtin.copy:
      src: miniokey
      dest: /home/vagrant/.ssh/miniokey
      owner: vagrant
      group: vagrant
      mode: '0600'

  - name: copy over ssh private key to root
    ansible.builtin.copy:
      src: miniokey
      dest: /root/.ssh/miniokey
      owner: root
      group: wheel
      mode: '0600'

  - name: copy over ssh public key
    ansible.builtin.copy:
      src: miniokey.pub
      dest: /home/vagrant/.ssh/miniokey.pub
      owner: vagrant
      group: vagrant
      mode: '0600'

  - name: copy over ssh public key to root
    ansible.builtin.copy:
      src: miniokey.pub
      dest: /root/.ssh/miniokey.pub
      owner: root
      group: wheel
      mode: '0600'

  - name: Append ssh pubkey to authorized_keys
    become: yes
    become_user: vagrant
    shell:
      chdir: /home/vagrant/
      cmd: |
        cat /home/vagrant/.ssh/miniokey.pub >> /home/vagrant/.ssh/authorized_keys

  - name: Append ssh pubkey to authorized_keys for root
    become: yes
    become_user: root
    shell:
      chdir: /root/
      cmd: |
        cat /root/.ssh/miniokey.pub >> /root/.ssh/authorized_keys

  - name: Create directory /usr/local/etc/ssl
    ansible.builtin.file:
      path: "{{ local_openssl_dir }}"
      state: directory
      mode: '0755'
      owner: root
      group: wheel

  - name: Create directory /usr/local/etc/ssl/CAs
    ansible.builtin.file:
      path: "{{ local_openssl_ca_dir }}"
      state: directory
      mode: '0755'
      owner: root
      group: wheel

  - name: Configure minio disk permissions disk 1
    ansible.builtin.file:
      path: "{{ local_minio_disk1 }}"
      state: directory
      mode: '0755'
      owner: minio
      group: minio

  - name: Configure minio disk permissions disk 2
    ansible.builtin.file:
      path: "{{ local_minio_disk2 }}"
      state: directory
      mode: '0755'
      owner: minio
      group: minio

  - name: Configure minio disk permissions disk 3
    ansible.builtin.file:
      path: "{{ local_minio_disk3 }}"
      state: directory
      mode: '0755'
      owner: minio
      group: minio

  - name: Configure minio disk permissions disk 4
    ansible.builtin.file:
      path: "{{ local_minio_disk4 }}"
      state: directory
      mode: '0755'
      owner: minio
      group: minio

- hosts: minio1
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Create ssh client config
    become: yes
    become_user: vagrant
    copy:
      dest: /home/vagrant/.ssh/config
      content: |
        Host {{ minio1_hostname }}
          # HostName {{ minio1_ip_address }}
          HostName {{ minio_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/miniokey
          # Port 22
          Port {{ minio1_ssh_port }}
          Compression no
          ServerAliveInterval 20

        Host {{ minio2_hostname }}
          # HostName {{ minio2_ip_address }}
          HostName {{ minio_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/miniokey
          # Port 22
          Port {{ minio2_ssh_port }}
          Compression no
          ServerAliveInterval 20

  - name: Create ssh client config for root user
    become: yes
    become_user: root
    copy:
      dest: /root/.ssh/config
      content: |
        Host {{ minio1_hostname }}
          # HostName {{ minio1_ip_address }}
          HostName {{ minio_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/miniokey
          Port {{ minio1_ssh_port }}
          ServerAliveInterval 20

        Host {{ minio2_hostname }}
          # HostName {{ minio2_ip_address }}
          HostName {{ minio_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/miniokey
          Port {{ minio2_ssh_port }}
          ServerAliveInterval 20

  - name: Setup openssl CA and generate root key
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_ca_dir }}"
      cmd: |
        openssl genrsa \
          -out {{ local_openssl_root_key }} {{ local_openssl_root_key_size }}

  - name: Setup openssl CA and generate root certificate
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_ca_dir }}"
      cmd: |
        openssl req \
          -sha256 \
          -new \
          -x509 \
          -days {{ local_openssl_root_key_expiry }} \
          -key {{ local_openssl_root_key }} \
          -out {{ local_openssl_root_cert }} \
          -subj /C=US/ST=None/L=City/O=Organisation/CN={{ minio1_hostname }}

  - name: Wait for ssh to become available on minio1
    become: yes
    become_user: root
    wait_for:
      host: "{{ minio_nat_gateway }}"
      port: "{{ minio1_ssh_port }}"
      delay: 10
      timeout: 120
      state: started

  - name: Run ssh-keyscan on minio2 (mitigating an error that crops up otherwise)
    become: yes
    become_user: root
    shell:
      cmd: |
        ssh-keyscan -T 20 -p {{ minio2_ssh_port }} {{ minio_nat_gateway }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Wait for ssh to become available minio2
    become: yes
    become_user: root
    wait_for:
      host: "{{ minio_nat_gateway }}"
      port: "{{ minio2_ssh_port }}"
      delay: 10
      timeout: 120
      state: started

  - name: Copy CA key to minio2
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_ca_dir }}"
      cmd: |
        rsync -avz {{ local_openssl_root_key }} root@{{ minio2_hostname }}:{{ local_openssl_ca_dir }}/

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Wait for ssh to become available minio2
    become: yes
    become_user: root
    wait_for:
      host: "{{ minio_nat_gateway}}"
      port: "{{ minio2_ssh_port }}"
      delay: 10
      timeout: 90
      state: started

  - name: Copy CA cert to minio2
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_ca_dir }}"
      cmd: |
        rsync -avz {{ local_openssl_root_cert }} root@{{ minio2_hostname }}:{{ local_openssl_ca_dir }}/

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Create /usr/local/etc/ssl/openssl.conf on minio1
    become: yes
    become_user: root
    copy:
      dest: "{{ local_openssl_dir }}/{{ local_openssl_conf }}"
      content: |
        basicConstraints = CA:FALSE
        nsCertType = server
        nsComment = "OpenSSL Generated Server Certificate"
        subjectKeyIdentifier = hash
        authorityKeyIdentifier = keyid,issuer:always
        keyUsage = critical, digitalSignature, keyEncipherment
        extendedKeyUsage = serverAuth
        subjectAltName = @alt_names
        [alt_names]
        IP.1 = {{ minio1_ip_address }}
        IP.2 = {{ minio_access_ip }}
        DNS.1 = {{ minio1_hostname }}

  - name: Generate certificates on minio1 round 1
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl genrsa \
          -out {{ local_openssl_private_key }} {{ local_openssl_client_key_size }}

  - name: Set minio ownership private key minio1
    ansible.builtin.file:
      path: "{{ local_openssl_dir }}/{{ local_openssl_private_key }}"
      mode: '0644'
      owner: minio
      group: minio

  - name: Generate certificates on minio1 round 2
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl req -new \
          -key {{ local_openssl_private_key }} \
          -out {{ local_openssl_public_cert }} \
          -subj /C=US/ST=None/L=City/O=Organisation/CN={{ minio1_hostname }}

  - name: Generate certificates on minio1 round 3
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl x509 -req \
          -in {{ local_openssl_public_cert }} \
          -CA CAs/{{ local_openssl_root_cert }} \
          -CAkey CAs/{{ local_openssl_root_key }} \
          -CAcreateserial \
          -out {{ local_openssl_public_cert }} \
          -days {{ local_openssl_client_key_expiry }} \
          -sha256 \
          -extfile {{ local_openssl_conf }}

  - name: Set minio ownership public key minio1
    ansible.builtin.file:
      path: "{{ local_openssl_dir }}/{{ local_openssl_public_cert }}"
      mode: '0644'
      owner: minio
      group: minio

  - name: Create certificate bundle for nginx on minio1
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        cat {{ local_openssl_public_cert }} CAs/{{ local_openssl_root_cert }} >> {{ local_openssl_nginx_cert }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Rehash certs minio1
    become: yes
    become_user: root
    shell:
      cmd: certctl rehash

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Update nginx.conf with proxy
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/nginx/nginx.conf
      content: |
        load_module /usr/local/libexec/nginx/ngx_stream_module.so;
        worker_processes  1;
        error_log /var/log/nginx/error.log;
        events {
          worker_connections 4096;
        }
        # removing in favour of haproxy
        # stream {
        #   upstream nextclouddb {
        #     server {{ mariadb_ip }}:3306;
        #   }
        #   server {
        #     listen "{{ mariadb_nc_proxy_port }}" proxy_protocol;
        #     proxy_pass nextclouddb;
        #     proxy_protocol on;
        #   }
        # }
        http {
          include mime.types;
          default_type application/octet-stream;
          sendfile on;
          keepalive_timeout 65;
          gzip off;
          server {
            listen 80;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            root /usr/local/www/sampler;
            index index.html;
            location / {
               try_files $uri $uri/ /index.html;
            }
          }
          server {
            listen 19000 ssl;
            ssl_certificate {{ local_openssl_dir }}/{{ local_openssl_nginx_cert }};
            ssl_certificate_key {{ local_openssl_dir }}/{{ local_openssl_private_key }};
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_ssl_verify off;
              proxy_pass https://{{ minio_nat_gateway }}:10901;
            }
          }
          server {
            listen 13000;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ beast_ip }}:3000;
            }
          }
          server {
            listen 19090;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ beast_ip }}:9090;
            }
          }
          server {
            listen 19093;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ beast_ip }}:9093;
            }
          }
          server {
            listen 14646;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ nomad_ip }}:4646;
            }
          }
          server {
            listen 18500;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ consul_ip }}:8500;
            }
          }
          server {
            listen 19002;
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ traefik_ip }}:9002;
            }
          }
          server {
            listen 443 ssl;
            ssl_certificate {{ local_openssl_dir }}/{{ local_openssl_nginx_cert }};
            ssl_certificate_key {{ local_openssl_dir }}/{{ local_openssl_private_key }};
            server_name {{ minio1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_ssl_verify off;
              proxy_pass http://{{ minio1_nomad_client_ip }}:10443;
            }
          }
        }

  - name: Create directory /usr/local/www/sampler
    ansible.builtin.file:
      path: /usr/local/www/sampler
      state: directory
      mode: '0755'
      owner: root
      group: wheel

  - name: Create default sampler index.html
    become: yes
    become_user: root
    copy:
      dest: /usr/local/www/sampler/index.html
      content: |
        <!DOCTYPE html>
        <html>
        <head>
        <title>Welcome to minio-sampler!</title>
        <style>
        html { color-scheme: light dark; }
        body { width: 35em; margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif; }
        </style>
        </head>
        <body>
        <h1>Welcome to minio-sampler!</h1>
        <p>Please choose from the following:</p>
        <ul>
          <li><a href="https://{{ minio_access_ip }}:19000">Minio dashboard</a></li>
          <li><a href="http://{{ minio_access_ip }}:13000">Grafana</a></li>
          <li><a href="http://{{ minio_access_ip }}:19090">Prometheus</a></li>
          <li><a href="http://{{ minio_access_ip }}:19093">Alertmanager</a></li>
          <li><a href="http://{{ minio_access_ip }}:14646">Nomad</a></li>
          <li><a href="http://{{ minio_access_ip }}:18500">Consul</a></li>
          <li><a href="http://{{ minio_access_ip }}:19002">Traefik</a></li>
          <li><a href="https://{{ minio_access_ip }}">Nextcloud</a></li>
        </ul>
        </body>
        </html>

  - name: Enable nginx
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nginx
      enabled: yes

  - name: Start nginx
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nginx
      state: started

  - name: Enable minio sysrc entries on minio1
    become: yes
    become_user: root
    shell:
      cmd: |
        service minio enable
        sysrc minio_certs="{{ local_openssl_dir }}"
        sysrc minio_syslog_enable="YES"
        sysrc minio_env="MINIO_ACCESS_KEY={{ minio_access_key }} MINIO_SECRET_KEY={{ minio_access_password }} MINIO_PROMETHEUS_AUTH_TYPE=public"
        sysrc minio_disks="{{ minio_erasure_coding_collection }}"

- hosts: minio2
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Create /usr/local/etc/ssl/openssl.conf on minio2
    become: yes
    become_user: root
    copy:
      dest: "{{ local_openssl_dir }}/{{ local_openssl_conf }}"
      content: |
        basicConstraints = CA:FALSE
        nsCertType = server
        nsComment = "OpenSSL Generated Server Certificate"
        subjectKeyIdentifier = hash
        authorityKeyIdentifier = keyid,issuer:always
        keyUsage = critical, digitalSignature, keyEncipherment
        extendedKeyUsage = serverAuth
        subjectAltName = @alt_names
        [alt_names]
        IP.1 = {{ minio2_ip_address }}
        IP.2 = {{ minio_access_ip }}
        DNS.1 = {{ minio2_hostname }}

  - name: Generate certificates on minio2 round 1
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl genrsa \
          -out {{ local_openssl_private_key }} {{ local_openssl_client_key_size }}

  - name: Set minio ownership private key minio2
    ansible.builtin.file:
      path: "{{ local_openssl_dir }}/{{ local_openssl_private_key }}"
      mode: '0644'
      owner: minio
      group: minio

  - name: Generate certificates on minio2 round 2
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl req -new \
          -key {{ local_openssl_private_key }} \
          -out {{ local_openssl_public_cert }} \
          -subj /C=US/ST=None/L=City/O=Organisation/CN={{ minio2_hostname }}

  - name: Generate certificates on minio2 round 3
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        openssl x509 -req \
          -in {{ local_openssl_public_cert }} \
          -CA CAs/{{ local_openssl_root_cert }} \
          -CAkey CAs/{{ local_openssl_root_key }} \
          -CAcreateserial \
          -out {{ local_openssl_public_cert }} \
          -days {{ local_openssl_client_key_expiry }} \
          -sha256 \
          -extfile {{ local_openssl_conf }}

  - name: Set minio ownership public key minio2
    ansible.builtin.file:
      path: "{{ local_openssl_dir }}/{{ local_openssl_public_cert }}"
      mode: '0644'
      owner: minio
      group: minio

  - name: Create certificate bundle for nginx on minio2
    become: yes
    become_user: root
    shell:
      chdir: "{{ local_openssl_dir }}"
      cmd: |
        cat {{ local_openssl_public_cert }} CAs/{{ local_openssl_root_cert }} >> {{ local_openssl_nginx_cert }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Rehash certs minio2
    become: yes
    become_user: root
    shell:
      cmd: certctl rehash

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Enable minio sysrc entries on minio2
    become: yes
    become_user: root
    shell:
      cmd: |
        service minio enable
        sysrc minio_certs="{{ local_openssl_dir }}"
        sysrc minio_syslog_enable="YES"
        sysrc minio_env="MINIO_ACCESS_KEY={{ minio_access_key }} MINIO_SECRET_KEY={{ minio_access_password }} MINIO_PROMETHEUS_AUTH_TYPE=public"
        sysrc minio_disks="{{ minio_erasure_coding_collection }}"

- hosts: all
  gather_facts: yes
  tasks:
  - name: Start minio
    become: yes
    become_user: root
    ansible.builtin.service:
      name: minio
      state: started

- hosts: minio1
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup minio aliases and initial bucket
    become: yes
    become_user: root
    shell:
      cmd: |
        env MINIO_ACCESS_KEY="{{ minio_access_key }}"
        env MINIO_SECRET_KEY="{{ minio_access_password }}"
        minio-client alias set {{ minio_resource }} https://{{ minio1_ip_address }}:9000 {{  minio_access_key }} {{ minio_access_password }} --api S3v4  --insecure --config-dir /root/.minio-client/
        minio-client mb --insecure  --config-dir /root/.minio-client/ --with-lock {{ minio_resource }}/{{ minio_dataset }}

  - name: Setup ZFS datasets
    become: yes
    become_user: root
    shell:
      cmd: |
        zfs create -o mountpoint=/mnt/srv zroot/srv
        zfs create -o mountpoint=/mnt/srv/pot zroot/srv/pot
        zfs create -o mountpoint=/mnt/data zroot/data
        zfs create -o mountpoint=/mnt/data/jaildata zroot/data/jaildata
        zfs create -o mountpoint=/mnt/data/jaildata/traefik zroot/data/jaildata/traefik
        zfs create -o mountpoint=/mnt/data/jaildata/beast zroot/data/jaildata/beast
        zfs create -o mountpoint=/mnt/data/jaildata/mariadb zroot/data/jaildata/mariadb
        mkdir -p /mnt/data/jaildata/mariadb/var_db_mysql
        zfs create -o mountpoint=/mnt/data/jaildata zroot/data/jaildata
        zfs create -o mountpoint=/mnt/data/jaildata/nextcloud zroot/data/jaildata/nextcloud
        zfs create -o mountpoint=/mnt/data/jaildata/nextcloud/nextcloud_www zroot/data/jaildata/nextcloud/nextcloud_www
        zfs create -o mountpoint=/mnt/data/jaildata/nextcloud/storage zroot/data/jaildata/nextcloud/storage
        mkdir -p /root/nomadjobs

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Install needed packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - consul
        - haproxy
        - nomad
        - nomad-pot-driver
        - node_exporter
        - pot
        - potnet
      state: present

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: HOTFIX temp fix to patch pot common.sh
    become: yes
    become_user: root
    shell:
      cmd: |
        cd /tmp
        git clone https://github.com/bsdpot/pot.git potpatch
        cp -f /tmp/potpatch/share/pot/*.sh /usr/local/share/pot/
        rm -rf potpatch
        fetch -o /tmp/common.sh.in "https://raw.githubusercontent.com/bretton/minio-sampler/main/includes/pot_common.sh"
        cp -f /tmp/common.sh.in /usr/local/share/pot/common.sh
        rm /tmp/common.sh.in

  - name: Setup pot.conf
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/pot/pot.conf
      content: |
        POT_ZFS_ROOT=zroot/srv/pot
        POT_FS_ROOT=/mnt/srv/pot
        POT_CACHE=/var/cache/pot
        POT_TMP=/tmp
        POT_NETWORK=10.192.0.0/10
        POT_NETMASK=255.192.0.0
        POT_GATEWAY=10.192.0.1
        POT_EXTIF=untrusted

  - name: Initiate pot
    become: yes
    become_user: root
    shell:
      cmd: |
        pot init -v

  - name: Enable pot
    become: yes
    become_user: root
    ansible.builtin.service:
      name: pot
      enabled: yes

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Make consul directory
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /usr/local/etc/consul.d

  - name: Set consul.d permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d"
      state: directory
      mode: '0750'
      owner: consul
      group: wheel

  - name: Setup consul client agent.json
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/consul.d/agent.json
      content: |
        {
          "bind_addr": "{{ minio1_ip_address }}",
          "server": false,
          "node_name": "{{ minio1_hostname }}",
          "datacenter": "{{ datacenter_name }}",
          "log_level": "WARN",
          "data_dir": "/var/db/consul",
          "verify_incoming": false,
          "verify_outgoing": false,
          "verify_server_hostname": false,
          "verify_incoming_rpc": false,
          "encrypt": "{{ gossip_key }}",
          "enable_syslog": true,
          "leave_on_terminate": true,
          "start_join": [
            "{{ consul_ip }}"
          ],
          "telemetry": {
            "prometheus_retention_time": "24h"
          },
          "service": {
            "name": "node-exporter",
            "tags": ["_app=host-server", "_service=node-exporter", "_hostname={{ minio1_hostname }}", "_datacenter={{ datacenter_name }}"],
            "port": 9100
          }
        }

  - name: Set consul agent.json permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d/agent.json"
      mode: '0644'
      owner: consul
      group: wheel

  - name: Create consul log file
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /var/log/consul
        touch /var/log/consul/consul.log

  - name: Enable consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      enabled: yes

  - name: Start consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup node exporter
    become: yes
    become_user: root
    shell:
      cmd: |
        pw useradd -n nodeexport -c 'nodeexporter user' -m -s /usr/bin/nologin -h -
        service node_exporter enable
        sysrc node_exporter_args="--log.level=warn"
        sysrc node_exporter_user=nodeexport
        sysrc node_exporter_group=nodeexport
        service node_exporter restart

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the consul pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ consul_base }} -t {{ consul_version }} -U {{ consul_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the consul pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone \
          -P {{ consul_pot_name }} \
          -p {{ consul_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ consul_ip }}"
        pot set-env -p {{ consul_clone_name }} \
          -E DATACENTER={{ datacenter_name }} \
          -E NODENAME={{ consul_nodename }} \
          -E IP={{ consul_ip }} \
          -E BOOTSTRAP={{ consul_bootstrap }} \
          -E PEERS={{ consul_peers }} \
          -E GOSSIPKEY={{ gossip_key }} \
          -E REMOTELOG={{ beast_ip }}
        pot set-attr -p {{ consul_clone_name }} -A start-at-boot -V True
        pot start {{ consul_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Restart consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      state: restarted

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Make nomadjobs directory
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /root/nomadjobs

  - name: Setup nextcloud.nomad
    become: yes
    become_user: root
    copy:
      dest: "{{ nomad_job_src }}"
      content: |
        job "nextcloud" {
          datacenters = ["{{ datacenter_name }}"]
          type        = "service"
          group "group1" {
            count = 1
            update {
              max_parallel = 1
              min_healthy_time = "30s"
              healthy_deadline = "10m"
              progress_deadline = "15m"
            }
            network {
              port "http" {
                static = "10443"
              }
            }
            task "nextcloud1" {
              driver = "pot"
              service {
                tags = ["nginx", "www", "nextcloud"]
                name = "nextcloud-server"
                port = "http"
                  check {
                    type     = "tcp"
                    name     = "tcp"
                    interval = "60s"
                    timeout  = "30s"
                  }
              }
              config {
                image = "{{ nextcloud_url }}"
                pot = "{{ nextcloud_base }}"
                tag = "{{ nextcloud_version }}"
                command = "/usr/local/bin/cook"
                args = ["-d","{{ nextcloud_storage_dest }}","-s","{{ nextcloud_minio }}"]
                copy = [
                  "{{ nextcloud_copy_objectstore_src }}:{{ nextcloud_copy_objectstore_dest }}",
                  "{{ nextcloud_copy_mysql_src }}:{{ nextcloud_copy_mysql_dest }}",
                  "{{ nextcloud_copy_custom_src }}:{{ nextcloud_copy_custom_dest }}",
                  "{{ nextcloud_rootca_src }}:{{ nextcloud_rootca_dest }}"
                ]
                mount = [
                  "{{ nextcloud_www_src }}:{{ nextcloud_www_dest }}",
                  "{{ nextcloud_storage_src }}:{{ nextcloud_storage_dest }}"
                ]
                port_map = {
                  http = "80"
                }
              }
              resources {
                cpu = 1000
                memory = 1000
              }
            }
          }
        }

  - name: Setup objectstore.config.php
    become: yes
    become_user: root
    copy:
      dest: "{{ nextcloud_copy_objectstore_src }}"
      content: |
        <?php
        $CONFIG = array (
          'objectstore' =>
           array (
            'class' => 'OC\\Files\\ObjectStore\\S3',
            'arguments' => array (
              'bucket' => '{{ minio_dataset }}', // your bucket name
              'autocreate' => true,
              'key'    => '{{ minio_access_key }}', // your key
              'secret' => '{{ minio_access_password }}', // your secret
              'use_ssl' => true,
              'region' => '',
              'hostname' => '{{ minio_access_ip }}',
              'port' => '19000',
              'use_path_style' => true,
            ),
          ),
        );

  - name: Setup mysql.config.php
    become: yes
    become_user: root
    copy:
      dest: "{{ nextcloud_copy_mysql_src }}"
      content: |
        <?php
        $CONFIG = array (
          'dbtype' => 'mysql',
          'version' => '{{ nextcloud_custom_version }}',
          'dbname' => '{{ mariadb_nc_db_name }}',
          'dbhost' => '{{ minio1_ip_address }}',
          'dbport' => '{{ mariadb_nc_proxy_port }}',
          'dbtableprefix' => 'oc_',
          'dbuser' => '{{ mariadb_nc_user }}',
          'dbpassword' => '{{ mariadb_nc_pass }}',
          'mysql.utf8mb4' => true,
        );

  - name: Setup custom.config.php
    become: yes
    become_user: root
    copy:
      dest: "{{ nextcloud_copy_custom_src }}"
      content: |
        <?php
        $CONFIG = array (
          'trusted_domains' =>
          array (
            0 => 'nextcloud.{{ minio1_hostname }}',
            1 => '{{ minio1_ip_address }}',
            2 => '{{ minio_access_ip }}',
            3 => '{{ mariadb_ip }}',
            4 => '{{ minio1_nomad_client_ip }}',
          ),
          'datadirectory' => '{{ nextcloud_storage_dest }}',
          'config_is_read_only' => false,
          'loglevel' => 1,
          'logfile' => '{{ nextcloud_storage_dest }}/nextcloud.log',
          'memcache.local' => '\OC\Memcache\APCu',
          'filelocking.enabled' => true,
          'overwrite.cli.url' => '',
          'overwritehost' => '',
          'overwriteprotocol' => 'https',
          'installed' => false,
          'mail_from_address' => 'nextcloud',
          'mail_smtpmode' => 'smtp',
          'mail_smtpauthtype' => 'PLAIN',
          'mail_domain' => '{{ minio1_hostname }}',
          'mail_smtphost' => '',
          'mail_smtpport' => '',
          'mail_smtpauth' => 1,
          'maintenance' => false,
          'theme' => '',
          'twofactor_enforced' => 'false',
          'twofactor_enforced_groups' =>
          array (
          ),
          'twofactor_enforced_excluded_groups' =>
          array (
            0 => 'no_2fa',
          ),
          'updater.release.channel' => 'stable',
          'ldapIgnoreNamingRules' => false,
          'ldapProviderFactory' => 'OCA\\User_LDAP\\LDAPProviderFactory',
          'encryption_skip_signature_check' => true,
          'encryption.key_storage_migrated' => false,
          'allow_local_remote_servers' => true,
          'mail_sendmailmode' => 'smtp',
          'mail_smtpname' => 'nextcloud@{{ minio1_hostname }}',
          'mail_smtppassword' => '',
          'mail_smtpsecure' => 'ssl',
          'app.mail.verify-tls-peer' => false,
          'app_install_overwrite' =>
          array (
            0 => 'camerarawpreviews',
            1 => 'keeweb',
            2 => 'calendar',
          ),
          'apps_paths' =>
            array (
              0 =>
                array (
                  'path' => '/usr/local/www/nextcloud/apps',
                  'url' => '/apps',
                  'writable' => true,
                ),
              1 =>
                array (
                 'path' => '/usr/local/www/nextcloud/apps-pkg',
                 'url' => '/apps-pkg',
                 'writable' => false,
                ),
            ),
        );

  - name: download the nextcloud pot image so it's already local
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ nextcloud_base }} -t {{ nextcloud_version }} -U {{ nextcloud_url }}

  - name: download the nomad pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ nomad_base }} -t {{ nomad_version }} -U {{ nomad_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the nomad pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone -P {{ nomad_pot_name }} \
          -p {{ nomad_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ nomad_ip }}"
        pot copy-in -p {{ nomad_clone_name }} \
          -s {{ nomad_job_src }} \
          -d {{ nomad_job_dest }}
        pot copy-in -p {{ nomad_clone_name }} \
          -s {{ nextcloud_copy_objectstore_src }} \
          -d {{ nextcloud_copy_objectstore_dest }}
        pot copy-in -p {{ nomad_clone_name }} \
          -s {{ nextcloud_copy_mysql_src }} \
          -d {{ nextcloud_copy_mysql_dest }}
        pot copy-in -p {{ nomad_clone_name }} \
          -s {{ nextcloud_copy_custom_src }} \
          -d {{ nextcloud_copy_custom_dest }}
        pot set-env -p {{ nomad_clone_name }} \
          -E NODENAME={{ nomad_nodename }} \
          -E DATACENTER={{ datacenter_name }} \
          -E IP={{ nomad_ip }} \
          -E CONSULSERVERS={{ consul_ip }} \
          -E BOOTSTRAP={{ nomad_bootstrap }} \
          -E GOSSIPKEY="{{ gossip_key }}" \
          -E REMOTELOG={{ beast_ip }} \
          -E IMPORTJOBS={{ nomad_importjobs }}
        pot set-attr -p {{ nomad_clone_name }} -A start-at-boot -V True
        pot start {{ nomad_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup nomad client.hcl minio1
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/nomad/client.hcl
      content: |
        bind_addr = "{{ minio1_nomad_client_ip }}"
        datacenter = "{{ datacenter_name }}"
        advertise {
          # This should be the IP of THIS MACHINE and must be routable by every node
          # in your cluster
          http = "{{ minio1_nomad_client_ip }}"
          rpc = "{{ minio1_nomad_client_ip }}"
        }
        client {
          enabled = true
          options {
            "driver.raw_exec.enable" = "1"
          }
          servers = ["{{ nomad_ip }}"]
        }
        plugin_dir = "/usr/local/libexec/nomad/plugins"
        consul {
          address = "127.0.0.1:8500"
          client_service_name = "{{ minio1_hostname }}"
          auto_advertise = true
          client_auto_join = true
        }
        tls {
          http = false
          rpc = false
          verify_server_hostname = false
          verify_https_client = false
        }
        telemetry {
          collection_interval = "15s"
          publish_allocation_metrics = true
          publish_node_metrics = true
          prometheus_metrics = true
          disable_hostname = true
        }
        enable_syslog=true
        log_level="WARN"
        syslog_facility="LOCAL1"

  - name: Set nomad client.hcl permissions
    ansible.builtin.file:
      path: "/usr/local/etc/nomad/client.hcl"
      mode: '0644'
      owner: nomad
      group: wheel

  - name: Remove nomad server.hcl
    become: yes
    become_user: root
    shell:
      cmd: |
        rm -r /usr/local/etc/nomad/server.hcl

  - name: Set nomad tmp permissions
    ansible.builtin.file:
      path: "/var/tmp/nomad"
      state: directory
      mode: '0700'
      owner: root
      group: wheel

  - name: setup nomad client log file
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /var/log/nomad
        touch /var/log/nomad/nomad.log

  - name: setup nomad client sysrc entries
    become: yes
    become_user: root
    shell:
      cmd: |
        sysrc nomad_user="root"
        sysrc nomad_group="wheel"
        sysrc nomad_env="PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin"
        sysrc nomad_args="-config=/usr/local/etc/nomad/client.hcl"
        sysrc nomad_debug="YES"

  - name: Enable nomad
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nomad
      enabled: yes

  - name: Start nomad
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nomad
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the traefik pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ traefik_base }} -t {{ traefik_version }} -U {{ traefik_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the traefik pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone -P {{ traefik_pot_name }} \
          -p {{ traefik_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ traefik_ip }}"
        pot set-env -p {{ traefik_clone_name }} \
          -E NODENAME={{ traefik_nodename }} \
          -E DATACENTER={{ datacenter_name }} \
          -E IP={{ traefik_ip }} \
          -E CONSULSERVERS={{ consul_ip }} \
          -E GOSSIPKEY="{{ gossip_key }}" \
          -E REMOTELOG="{{ beast_ip }}"
        pot set-attr -p {{ traefik_clone_name }} -A start-at-boot -V True
        pot mount-in -p {{ traefik_clone_name }} -m /var/log/traefik -d {{ traefik_mount_in }}
        pot start {{ traefik_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the mariadb pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ mariadb_base }} -t {{ mariadb_version }} -U {{ mariadb_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the mariadb pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone -P {{ mariadb_pot_name }} \
          -p {{ mariadb_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ mariadb_ip }}"
        pot mount-in -p {{ mariadb_clone_name }} \
          -d {{ mariadb_mount_in }} \
          -m {{ mariadb_mount_dest }}
        pot set-env -p {{ mariadb_clone_name }} \
          -E DATACENTER={{ datacenter_name }} \
          -E NODENAME={{ mariadb_nodename }} \
          -E IP={{ mariadb_ip }} \
          -E CONSULSERVERS='{{ consul_ip }}' \
          -E GOSSIPKEY='{{ gossip_key }}' \
          -E DBROOTPASS={{ mariadb_rootpass }} \
          -E DBSCRAPEPASS={{ mariadb_scrapepass }} \
          -E DUMPSCHEDULE="{{ mariadb_dumpschedule }}" \
          -E DUMPUSER={{ mariadb_dumpuser }} \
          -E DUMPFILE={{ mariadb_dumpfile }} \
          -E REMOTELOG="{{ beast_ip }}"
        pot set-attr -p {{ mariadb_clone_name }} -A start-at-boot -V True
        pot start {{ mariadb_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Copy over preparedatabase.sh script
    become: yes
    become_user: root
    copy:
      dest: /root/preparedatabase.sh
      content: |
        #!/bin/sh
        idmariadb=$(jls | grep {{ mariadb_clone_name }} | cut -c 1-8 | sed 's/[[:blank:]]*$//')
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "DROP DATABASE IF EXISTS {{ mariadb_nc_db_name }}"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "CREATE DATABASE {{ mariadb_nc_db_name }} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "CREATE USER {{ mariadb_nc_user }}@'localhost' IDENTIFIED BY '{{ mariadb_nc_pass }}'"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "GRANT ALL PRIVILEGES on *.* to {{ mariadb_nc_user }}@'localhost' IDENTIFIED BY '{{ mariadb_nc_pass }}' WITH GRANT OPTION"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "CREATE USER {{ mariadb_nc_user }}@'%' IDENTIFIED BY '{{ mariadb_nc_pass }}'"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "GRANT ALL PRIVILEGES on *.* to {{ mariadb_nc_user }}@'%' IDENTIFIED BY '{{ mariadb_nc_pass }}' WITH GRANT OPTION"
        jexec -U root "$idmariadb" /usr/local/bin/mysql -sfu root -e "FLUSH PRIVILEGES"

  - name: Set preparedatabase.sh permissions
    ansible.builtin.file:
      path: "/root/preparedatabase.sh"
      mode: '0755'
      owner: root
      group: wheel

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Copy over preparenextcloud.sh script
    become: yes
    become_user: root
    copy:
      dest: /root/preparenextcloud.sh
      content: |
        #!/bin/sh
        idnextcloud=$(jls | grep nextcloud | cut -c 1-8 |sed 's/[[:blank:]]*$//')
        jexec -U root "$idnextcloud" rm -r /usr/local/www/nextcloud/config/config.php
        jexec -U root "$idnextcloud" su -m www -c 'cd /usr/local/www/nextcloud/; \
          php occ maintenance:install \
          --database "mysql" \
          --database-name "{{ mariadb_nc_db_name }}" \
          --database-host "{{ minio1_ip_address }}" \
          --database-port "{{ mariadb_nc_proxy_port }}" \
          --database-user "{{ mariadb_nc_user }}" \
          --database-pass "{{ mariadb_nc_pass }}" \
          --database-table-space "oc_" \
          --admin-user "{{ nextcloud_admin_user }}" \
          --admin-pass "{{ nextcloud_admin_pass }}" \
          --data-dir "{{ nextcloud_storage_dest }}"'

  - name: Set preparenextcloud.sh permissions
    ansible.builtin.file:
      path: "/root/preparenextcloud.sh"
      mode: '0755'
      owner: root
      group: wheel

  - name: Install needed packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - haproxy
      state: present

  - name: Make haproxy directories
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /usr/local/etc/haproxy
        mkdir -p /var/run/haproxy

  - name: Add haproxy.conf
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/haproxy/haproxy.conf
      content: |
        global
          daemon
          user www
          group www
          stats socket /var/run/haproxy/socket mode 600 level admin expose-fd listeners

        defaults
          retries 3
          option redispatch
          option tcplog
          timeout connect 10000ms
          timeout client 100000ms
          timeout server 100000ms

        listen mysql
          #bind {{ minio_access_ip }}:{{ mariadb_nc_proxy_port }}
          bind {{ minio1_ip_address }}:{{ mariadb_nc_proxy_port }}
          mode tcp
          server mariadb {{ mariadb_ip }}:{{ mariadb_nc_proxy_port }}

  - name: Configure haproxy start
    become: yes
    become_user: root
    shell:
      cmd: |
        sysrc haproxy_config=/usr/local/etc/haproxy/haproxy.conf
        service haproxy enable

  - name: Start haproxy
    become: yes
    become_user: root
    ansible.builtin.service:
      name: haproxy
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the beast-of-argh pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ beast_base }} -t {{ beast_version }} -U {{ beast_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the beast of argh pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone -P {{ beast_pot_name }} \
          -p {{ beast_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ beast_ip }}"
        pot mount-in -p {{ beast_clone_name }} \
          -d {{ beast_mount_in }} \
          -m {{ beast_mount_dest }}
        pot set-env -p {{ beast_clone_name }} \
          -E DATACENTER={{ datacenter_name }} \
          -E NODENAME={{ beast_nodename }} \
          -E IP={{ beast_ip }} \
          -E CONSULSERVERS="{{ beast_join_consul }}" \
          -E GOSSIPKEY="{{ gossip_key }}" \
          -E GRAFANAUSER={{ beast_grafana_user }} \
          -E GRAFANAPASSWORD={{ beast_grafana_pass }} \
          -E SCRAPECONSUL="{{ beast_scrape_consul }}" \
          -E SCRAPENOMAD="{{ beast_scrape_nomad }}" \
          -E TRAEFIKSERVER="{{ beast_scrape_traefik }}" \
          -E SMTPHOSTPORT="{{ beast_smtphostport }}" \
          -E SMTPFROM="{{ beast_smtp_from }}" \
          -E ALERTADDRESS="{{ beast_alertaddress }}" \
          -E SMTPUSER="{{ beast_smtp_user }}" \
          -E SMTPPASS="{{ beast_smtp_pass }}" \
          -E REMOTELOG={{ beast_ip }}
        pot set-attribute -p {{ beast_clone_name }} -A start-at-boot -V YES
        pot start {{ beast_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup syslog-ng.conf on minio1
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/syslog-ng.conf
      content: |
        @version: "{{ beast_syslog_version }}"
        @include "scl.conf"
        # options
        options {
         chain_hostnames(off);
         use_dns (no);
         dns-cache(no);
         use_fqdn (no);
         keep_hostname(no);
         flush_lines(0);
         threaded(yes);
         log-fifo-size(2000);
         stats_freq(0);
         time_reopen(120);
         ts_format(iso);
        };
        source src {
         system();
         internal();
        };
        source s_otherlogs {
         file("/var/log/consul/consul.log");
         file("/var/log/nomad/nomad.log");
        };
        destination messages { file("/var/log/messages"); };
        destination security { file("/var/log/security"); };
        destination authlog { file("/var/log/auth.log"); };
        destination maillog { file("/var/log/maillog"); };
        destination lpd-errs { file("/var/log/lpd-errs"); };
        destination xferlog { file("/var/log/xferlog"); };
        destination cron { file("/var/log/cron"); };
        destination debuglog { file("/var/log/debug.log"); };
        destination consolelog { file("/var/log/console.log"); };
        destination all { file("/var/log/all.log"); };
        destination newscrit { file("/var/log/news/news.crit"); };
        destination newserr { file("/var/log/news/news.err"); };
        destination newsnotice { file("/var/log/news/news.notice"); };
        destination slip { file("/var/log/slip.log"); };
        destination ppp { file("/var/log/ppp.log"); };
        #destination console { file("/dev/console"); };
        destination allusers { usertty("*"); };
        destination loghost {
          tcp(
            "{{ beast_ip }}"
            port(514)
            disk-buffer(
              mem-buf-size(134217728)   # 128MiB
              disk-buf-size(2147483648) # 2GiB
              reliable(yes)
              dir("/var/log/syslog-ng-disk-buffer")
            )
          );
        };
        filter f_auth { facility(auth); };
        filter f_authpriv { facility(authpriv); };
        filter f_not_authpriv { not facility(authpriv); };
        #filter f_console { facility(console); };
        filter f_cron { facility(cron); };
        filter f_daemon { facility(daemon); };
        filter f_ftp { facility(ftp); };
        filter f_kern { facility(kern); };
        filter f_lpr { facility(lpr); };
        filter f_mail { facility(mail); };
        filter f_news { facility(news); };
        filter f_security { facility(security); };
        filter f_user { facility(user); };
        filter f_uucp { facility(uucp); };
        filter f_local0 { facility(local0); };
        filter f_local1 { facility(local1); };
        filter f_local2 { facility(local2); };
        filter f_local3 { facility(local3); };
        filter f_local4 { facility(local4); };
        filter f_local5 { facility(local5); };
        filter f_local6 { facility(local6); };
        filter f_local7 { facility(local7); };
        filter f_emerg { level(emerg); };
        filter f_alert { level(alert..emerg); };
        filter f_crit { level(crit..emerg); };
        filter f_err { level(err..emerg); };
        filter f_warning { level(warning..emerg); };
        filter f_notice { level(notice..emerg); };
        filter f_info { level(info..emerg); };
        filter f_debug { level(debug..emerg); };
        filter f_is_debug { level(debug); };
        filter f_ppp { program("ppp"); };
        filter f_all {
          level(debug..emerg) and not (program("devd") and level(debug..info) ); };
        log {
          source(src);
          filter(f_notice);
          filter(f_not_authpriv);
          destination(messages);
        };
        log { source(src); filter(f_kern); filter(f_debug); destination(messages); };
        log { source(src); filter(f_lpr); filter(f_info); destination(messages); };
        log { source(src); filter(f_mail); filter(f_crit); destination(messages); };
        log { source(src); filter(f_security); destination(security); };
        log { source(src); filter(f_auth); filter(f_info); destination(authlog); };
        log { source(src); filter(f_authpriv); filter(f_info); destination(authlog); };
        log { source(src); filter(f_mail); filter(f_info); destination(maillog); };
        log { source(src); filter(f_lpr); filter(f_info); destination(lpd-errs); };
        log { source(src); filter(f_ftp); filter(f_info); destination(xferlog); };
        log { source(src); filter(f_cron); destination(cron); };
        log { source(src); filter(f_is_debug); destination(debuglog); };
        log { source(src); filter(f_emerg); destination(allusers); };
        log { source(src); filter(f_ppp); destination(ppp); };
        log { source(src); filter(f_all); destination(loghost); };
        log { source(s_otherlogs); destination(loghost); };

  - name: setup syslog-ng
    become: yes
    become_user: root
    shell:
      cmd: |
        service syslogd onestop
        service syslogd disable
        service syslog-ng enable
        sysrc syslog_ng_flags="-R /tmp/syslog-ng.persist"
        service syslog-ng restart

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

- hosts: minio2
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup ZFS datasets and nomadjobs directory
    become: yes
    become_user: root
    shell:
      cmd: |
        zfs create -o mountpoint=/mnt/srv zroot/srv
        zfs create -o mountpoint=/mnt/srv/pot zroot/srv/pot
        zfs create -o mountpoint=/mnt/data zroot/data

  - name: Install packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - consul
        - node_exporter
      state: present

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Make consul directory
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /usr/local/etc/consul.d

  - name: Set consul.d permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d"
      state: directory
      mode: '0750'
      owner: consul
      group: wheel

  - name: Setup consul client agent.json
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/consul.d/agent.json
      content: |
        {
          "bind_addr": "{{ minio2_ip_address }}",
          "server": false,
          "node_name": "{{ minio2_hostname }}",
          "datacenter": "{{ datacenter_name }}",
          "log_level": "WARN",
          "data_dir": "/var/db/consul",
          "verify_incoming": false,
          "verify_outgoing": false,
          "verify_server_hostname": false,
          "verify_incoming_rpc": false,
          "encrypt": "{{ gossip_key }}",
          "enable_syslog": true,
          "leave_on_terminate": true,
          "start_join": [
            "{{ consul_ip }}"
          ],
          "telemetry": {
            "prometheus_retention_time": "24h"
          },
          "service": {
            "name": "node-exporter",
            "tags": ["_app=host-server", "_service=node-exporter", "_hostname={{ minio2_hostname }}", "_datacenter={{ datacenter_name }}"],
            "port": 9100
          }
        }

  - name: Set consul agent.json permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d/agent.json"
      mode: '0644'
      owner: consul
      group: wheel

  - name: Create consul log file
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /var/log/consul
        touch /var/log/consul/consul.log

  - name: Enable consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      enabled: yes

  - name: Start consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup node exporter
    become: yes
    become_user: root
    shell:
      cmd: |
        pw useradd -n nodeexport -c 'nodeexporter user' -m -s /usr/bin/nologin -h -
        service node_exporter enable
        sysrc node_exporter_args="--log.level=warn"
        sysrc node_exporter_user=nodeexport
        sysrc node_exporter_group=nodeexport
        service node_exporter restart

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup syslog-ng.conf on minio2
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/syslog-ng.conf
      content: |
        @version: "{{ beast_syslog_version }}"
        @include "scl.conf"
        # options
        options {
         chain_hostnames(off);
         use_dns (no);
         dns-cache(no);
         use_fqdn (no);
         keep_hostname(no);
         flush_lines(0);
         threaded(yes);
         log-fifo-size(2000);
         stats_freq(0);
         time_reopen(120);
         ts_format(iso);
        };
        source src {
         system();
         internal();
        };
        destination messages { file("/var/log/messages"); };
        destination security { file("/var/log/security"); };
        destination authlog { file("/var/log/auth.log"); };
        destination maillog { file("/var/log/maillog"); };
        destination lpd-errs { file("/var/log/lpd-errs"); };
        destination xferlog { file("/var/log/xferlog"); };
        destination cron { file("/var/log/cron"); };
        destination debuglog { file("/var/log/debug.log"); };
        destination consolelog { file("/var/log/console.log"); };
        destination all { file("/var/log/all.log"); };
        destination newscrit { file("/var/log/news/news.crit"); };
        destination newserr { file("/var/log/news/news.err"); };
        destination newsnotice { file("/var/log/news/news.notice"); };
        destination slip { file("/var/log/slip.log"); };
        destination ppp { file("/var/log/ppp.log"); };
        #destination console { file("/dev/console"); };
        destination allusers { usertty("*"); };
        destination loghost {
          tcp(
            "{{ beast_ip }}"
            port(514)
            disk-buffer(
              mem-buf-size(134217728)   # 128MiB
              disk-buf-size(2147483648) # 2GiB
              reliable(yes)
              dir("/var/log/syslog-ng-disk-buffer")
            )
          );
        };
        filter f_auth { facility(auth); };
        filter f_authpriv { facility(authpriv); };
        filter f_not_authpriv { not facility(authpriv); };
        #filter f_console { facility(console); };
        filter f_cron { facility(cron); };
        filter f_daemon { facility(daemon); };
        filter f_ftp { facility(ftp); };
        filter f_kern { facility(kern); };
        filter f_lpr { facility(lpr); };
        filter f_mail { facility(mail); };
        filter f_news { facility(news); };
        filter f_security { facility(security); };
        filter f_user { facility(user); };
        filter f_uucp { facility(uucp); };
        filter f_local0 { facility(local0); };
        filter f_local1 { facility(local1); };
        filter f_local2 { facility(local2); };
        filter f_local3 { facility(local3); };
        filter f_local4 { facility(local4); };
        filter f_local5 { facility(local5); };
        filter f_local6 { facility(local6); };
        filter f_local7 { facility(local7); };
        filter f_emerg { level(emerg); };
        filter f_alert { level(alert..emerg); };
        filter f_crit { level(crit..emerg); };
        filter f_err { level(err..emerg); };
        filter f_warning { level(warning..emerg); };
        filter f_notice { level(notice..emerg); };
        filter f_info { level(info..emerg); };
        filter f_debug { level(debug..emerg); };
        filter f_is_debug { level(debug); };
        filter f_ppp { program("ppp"); };
        filter f_all {
          level(debug..emerg) and not (program("devd") and level(debug..info) ); };
        log {
          source(src);
          filter(f_notice);
          filter(f_not_authpriv);
          destination(messages);
        };
        log { source(src); filter(f_kern); filter(f_debug); destination(messages); };
        log { source(src); filter(f_lpr); filter(f_info); destination(messages); };
        log { source(src); filter(f_mail); filter(f_crit); destination(messages); };
        log { source(src); filter(f_security); destination(security); };
        log { source(src); filter(f_auth); filter(f_info); destination(authlog); };
        log { source(src); filter(f_authpriv); filter(f_info); destination(authlog); };
        log { source(src); filter(f_mail); filter(f_info); destination(maillog); };
        log { source(src); filter(f_lpr); filter(f_info); destination(lpd-errs); };
        log { source(src); filter(f_ftp); filter(f_info); destination(xferlog); };
        log { source(src); filter(f_cron); destination(cron); };
        log { source(src); filter(f_is_debug); destination(debuglog); };
        log { source(src); filter(f_emerg); destination(allusers); };
        log { source(src); filter(f_ppp); destination(ppp); };
        log { source(src); filter(f_all); destination(loghost); };

  - name: setup syslog-ng
    become: yes
    become_user: root
    shell:
      cmd: |
        service syslogd onestop
        service syslogd disable
        service syslog-ng enable
        sysrc syslog_ng_flags="-R /tmp/syslog-ng.persist"
        service syslog-ng restart

- hosts: minio1
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Create minio1 pf.conf
    become: yes
    become_user: root
    copy:
      dest: /etc/pf.conf
      content: |
        ext_if = "untrusted"
        set block-policy drop
        set skip on lo0
        scrub in all
        block
        antispoof for $ext_if inet
        antispoof for jailnet inet
        antispoof for compute inet
        pass inet proto icmp icmp-type {echorep, echoreq, unreach, squench, timex}
        pass on $ext_if inet6 proto icmp6 icmp6-type {unreach, toobig, neighbrsol, neighbradv, echoreq, echorep, timex}
        pass in on $ext_if inet proto udp from port = 68 to port = 67
        pass out on $ext_if inet proto udp from port = 67 to port = 68
        pass in quick on $ext_if proto tcp from any to port 22
        pass out on $ext_if proto tcp from port 22 to any flags any
        pass in on $ext_if proto tcp from any to port 80
        pass out on $ext_if proto tcp from port 80 to any flags any
        pass in on $ext_if proto tcp from any to port 443
        pass out on $ext_if proto tcp from port 443 to any flags any
        pass in on $ext_if proto tcp from any to port 3306
        pass out on $ext_if proto tcp from port 3306 to any flags any
        pass in on $ext_if proto tcp from any to port 9000
        pass out on $ext_if proto tcp from port 9000 to any flags any
        pass in on $ext_if proto tcp from any to port 10443
        pass out on $ext_if proto tcp from port 10443 to any flags any
        pass on jailnet
        pass on compute
        pass on bridge0
        pass in on $ext_if from 10.100.1/24
        pass from 10.192/10 to any
        pass from 10.200.1/24 to any
        pass from 10.200.2/24 to any
        pass out on $ext_if
  
  - name: Enable pf on minio1
    become: yes
    become_user: root
    ansible.builtin.service:
      name: pf
      enabled: yes

  - name: Enable pflog on minio1
    become: yes
    become_user: root
    ansible.builtin.service:
      name: pflog
      enabled: yes

  - name: Start pf on minio1
    become: yes
    become_user: root
    ansible.builtin.service:
      name: pf
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Run preparedatabase.sh script
    become: yes
    become_user: root
    shell:
      cmd: /root/preparedatabase.sh

  - name: Add minio1 hosts to prometheus monitoring from outside jail
    become: yes
    become_user: root
    copy:
      dest: /mnt/data/jaildata/beast/prometheus/targets.d/minio.yml
      content: |
        - targets:
          - {{ minio1_ip_address }}:9000
          labels:
            job: minio

  - name: Add mysql host to prometheus monitoring from outside jail
    become: yes
    become_user: root
    copy:
      dest: /mnt/data/jaildata/beast/prometheus/targets.d/mysql.yml
      content: |
        - targets:
          - {{ mariadb_ip }}:9104
          labels:
            job: mysql

  - name: Add script to reload prometheus inside jail to minio1
    become: yes
    become_user: root
    copy:
      dest: /root/reloadprometheus.sh
      content: |
        #!/bin/sh
        idbeast=$(jls | grep {{ beast_clone_name }} | cut -c 1-8 | sed 's/[[:blank:]]*$//')
        jexec -U root "$idbeast" service prometheus reload

  - name: Set prometheus reload script permissions on minio1
    ansible.builtin.file:
      path: "/root/reloadprometheus.sh"
      mode: '0755'
      owner: root
      group: wheel

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: reload prometheus inside the beast jail on minio1
    become: yes
    become_user: root
    shell:
      cmd: /root/reloadprometheus.sh

EOF

step "Create Vagrantfile"
cat >Vagrantfile<<EOV
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "minio1", primary: true do |node|
    node.vm.hostname = 'minio1'
    node.vm.boot_timeout = 600
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.ssh.forward_agent = false
    node.vm.communicator = "ssh"
    node.ssh.connect_timeout = 60
    node.ssh.keep_alive = true
    node.disksize.size = '32GB'
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "8"
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["modifyvm", :id, "--audio", "none"]
      vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype3", "virtio"]
      vb.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["createhd", "--filename", "minio1-disk1.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd", "--medium", "minio1-disk1.vdi"]
      vb.customize ["createhd", "--filename", "minio1-disk2.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2, "--device", 0, "--type", "hdd", "--medium", "minio1-disk2.vdi"]
      vb.customize ["createhd", "--filename", "minio1-disk3.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 3, "--device", 0, "--type", "hdd", "--medium", "minio1-disk3.vdi"]
      vb.customize ["createhd", "--filename", "minio1-disk4.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 4, "--device", 0, "--type", "hdd", "--medium", "minio1-disk4.vdi"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = "virtio"
    node.vm.network :forwarded_port, guest: 22, host_ip: "${NETWORK}.1", host: 12222, id: "minio1-ssh"
    node.vm.network :forwarded_port, guest: 9000, host_ip: "${NETWORK}.1", host: 10901, id: "minio1-minio"
    node.vm.network :forwarded_port, guest: 10443, host_ip: "${NETWORK}.1", host: 10906, id: "minio1-nextcloud"
    node.vm.network :forwarded_port, guest: 9000, host_ip: "${ACCESSIP}", host: 29000, id: "minio1-minio-public"
    end
    node.vm.network :private_network, ip: "${NETWORK}.3", auto_config: false
    node.vm.network :public_network, ip: "${ACCESSIP}", auto_config: false
    node.vm.provision "shell", run: "always", inline: <<-SHELL
      sysrc ipv6_network_interfaces="none"
      ifconfig vtnet0 name untrusted
      ifconfig vtnet1 "${NETWORK}.3" netmask 255.255.255.0 up
      ifconfig vtnet2 "${ACCESSIP}" netmask 255.255.255.0 up
      sysrc ifconfig_vtnet0_name="untrusted"
      sysrc ifconfig_untrusted="SYNCDHCP"
      sysrc ifconfig_vtnet1="inet ${NETWORK}.3 netmask 255.255.255.0"
      sysrc ifconfig_vtnet2="inet ${ACCESSIP} netmask 255.255.255.0"
      sysrc defaultrouter="${GATEWAY}"
      sysrc gateway_enable="YES"
      sed -i ".orig" -e "s|files mdns dns|files mdns_minimal [NOTFOUND=return] dns mdns|g" /etc/nsswitch.conf
      sysctl -w security.jail.allow_raw_sockets=1
      sysctl -w net.inet.tcp.msl=3000
      sysctl -w net.inet.tcp.tolerate_missing_ts=1
      echo "security.jail.allow_raw_sockets=1" >> /etc/sysctl.conf
      echo "net.inet.tcp.msl=3000" >> /etc/sysctl.conf
      echo "net.inet.tcp.tolerate_missing_ts=1" >> /etc/sysctl.conf
      service netif restart && service routing restart
      ifconfig jailnet create vlan 1001 vlandev untrusted
      ifconfig jailnet inet 10.200.1.1/24 up
      ifconfig compute create vlan 1006 vlandev untrusted
      ifconfig compute inet 10.200.2.1/24 up
      sysrc vlans_untrusted="jailnet compute"
      sysrc create_args_jailnet="vlan 1001"
      sysrc ifconfig_jailnet="inet 10.200.1.1/24"
      sysrc create_args_compute="vlan 1006"
      sysrc ifconfig_compute="inet 10.200.2.1/24"
      sysrc static_routes="jailstatic computestatic"
      sysrc route_jailstatic="-net 10.200.1.0/24 10.200.1.1"
      sysrc route_computestatic="-net 10.200.2.0/24 10.200.2.1"
      service netif restart && service routing restart
      echo "checking DNS resolution with ping"
      ping -c 1 google.com
      mkdir -p /mnt/minio
      gpart create -s GPT ada1
      gpart add -t freebsd-zfs -l minio-disk1 ada1
      zpool create -m /mnt/minio/disk1 minio-disk1 ada1p1
      gpart create -s GPT ada2
      gpart add -t freebsd-zfs -l minio-disk2 ada2
      zpool create -m /mnt/minio/disk2 minio-disk2 ada2p1
      gpart create -s GPT ada3
      gpart add -t freebsd-zfs -l minio-disk3 ada3
      zpool create -m /mnt/minio/disk3 minio-disk3 ada3p1
      gpart create -s GPT ada4
      gpart add -t freebsd-zfs -l minio-disk4 ada4
      zpool create -m /mnt/minio/disk4 minio-disk4 ada4p1
    SHELL
  end
  config.vm.define "minio2", primary: false do |node|
    node.vm.hostname = 'minio2'
    node.vm.boot_timeout = 600
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.ssh.forward_agent = false
    node.vm.communicator = "ssh"
    node.ssh.connect_timeout = 60
    node.ssh.keep_alive = true
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "4"
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["modifyvm", :id, "--audio", "none"]
      vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      vb.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["createhd", "--filename", "minio2-disk1.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd", "--medium", "minio2-disk1.vdi"]
      vb.customize ["createhd", "--filename", "minio2-disk2.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2, "--device", 0, "--type", "hdd", "--medium", "minio2-disk2.vdi"]
      vb.customize ["createhd", "--filename", "minio2-disk3.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 3, "--device", 0, "--type", "hdd", "--medium", "minio2-disk3.vdi"]
      vb.customize ["createhd", "--filename", "minio2-disk4.vdi", "--size", "${DISKSIZE}"]
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 4, "--device", 0, "--type", "hdd", "--medium", "minio2-disk4.vdi"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = "virtio"
    node.vm.network :forwarded_port, guest: 22, host_ip: "${NETWORK}.1", host: 12223, id: "minio2-ssh"
    node.vm.network :forwarded_port, guest: 9000, host_ip: "${NETWORK}.1", host: 10902, id: "minio2-minio"
    end
    node.vm.network :private_network, ip: "${NETWORK}.4", auto_config: false
    node.vm.provision "shell", run: "always", inline: <<-SHELL
      sysrc ipv6_network_interfaces="none"
      ifconfig vtnet0 name untrusted
      ifconfig vtnet1 "${NETWORK}.4" netmask 255.255.255.0 up
      sysrc ifconfig_vtnet0_name="untrusted"
      sysrc ifconfig_untrusted="SYNCDHCP"
      sysrc ifconfig_vtnet1="inet ${NETWORK}.4 netmask 255.255.255.0"
      sysrc defaultrouter="${GATEWAY}"
      sysrc gateway_enable="YES"
      sed -i ".orig" -e "s|files mdns dns|files mdns_minimal [NOTFOUND=return] dns mdns|g" /etc/nsswitch.conf
      sysctl -w security.jail.allow_raw_sockets=1
      sysctl -w net.inet.tcp.msl=3000
      sysctl -w net.inet.tcp.tolerate_missing_ts=1
      echo "security.jail.allow_raw_sockets=1" >> /etc/sysctl.conf
      echo "net.inet.tcp.msl=3000" >> /etc/sysctl.conf
      echo "net.inet.tcp.tolerate_missing_ts=1" >> /etc/sysctl.conf
      service netif restart && service routing restart
      echo "checking DNS resolution with ping"
      ping -c 1 google.com
      mkdir -p /mnt/minio
      gpart create -s GPT ada1
      gpart add -t freebsd-zfs -l minio-disk1 ada1
      zpool create -m /mnt/minio/disk1 minio-disk1 ada1p1
      gpart create -s GPT ada2
      gpart add -t freebsd-zfs -l minio-disk2 ada2
      zpool create -m /mnt/minio/disk2 minio-disk2 ada2p1
      gpart create -s GPT ada3
      gpart add -t freebsd-zfs -l minio-disk3 ada3
      zpool create -m /mnt/minio/disk3 minio-disk3 ada3p1
      gpart create -s GPT ada4
      gpart add -t freebsd-zfs -l minio-disk4 ada4
      zpool create -m /mnt/minio/disk4 minio-disk4 ada4p1
    SHELL
    node.vm.provision 'ansible' do |ansible|
    ansible.compatibility_mode = '2.0'
    ansible.limit = 'all'
    ansible.playbook = 'site.yml'
    ansible.become = true
    ansible.verbose = ''
    ansible.config_file = 'ansible.cfg'
    ansible.raw_ssh_args = "-o ControlMaster=no -o IdentitiesOnly=yes -o ConnectionAttempts=20 -o ConnectTimeout=60 -o ServerAliveInterval=20"
    ansible.raw_arguments = [ "--timeout=1000" ]
    ansible.groups = {
      "all" => [ "minio1", "minio2" ],
        "all:vars" => {
        "ansible_python_interpreter" => "/usr/local/bin/python"
      },
    }
    end
  end
end
EOV

step "Create potman.ini"
cat >potman.ini<<EOP
[sampler]
name="${SAMPLER_NAME}"
vm_manager="vagrant"
freebsd_version="${FREEBSD_VERSION}"
network="${NETWORK}"
gateway="${GATEWAY}"
EOP

step "Creating ansible.cfg"
cat >ansible.cfg<<EOCFG
[defaults]
host_key_checking = False
timeout = 30
log_path = ansible.log
[ssh_connection]
retries=10
scp_if_ssh = True
EOCFG


step "Create gitignore file"
cat >.gitignore<<EOG
*~
.vagrant
_build
ansible.tgz
ansible.log
ansible.cfg
pubkey.asc
secret.asc
id_rsa
id_rsa.pub
miniokey
miniokey.pub
EOG

step "Success"

echo "Created sampler ${SAMPLER_NAME}"
