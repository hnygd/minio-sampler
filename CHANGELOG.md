0.138

* Include link to blog post

---

0.137

* New version nextcloud nomad image

---

0.136

* Automatically grow disk on first boot added in

---

0.135

* Updating ERRATA file

---

0.134

* Set packer log path

---

0.133

* Fix detailed documentation

---

0.132

* Fix ansible labelling
* Add back vagrant disksize plugin because disk too small

---

0.131

* Update nextcloud version, now using non-layered image with latest package sources

---

0.130

* Change IP for haproxy to mariadb
* Adjust database users

---

0.129

* Using haproxy instead of nginx to proxy mariadb

---

0.128

* Update nextcloud version again

---

0.127

* Update nextcloud version

---

0.126

* Enable filelocking setting for nextcloud

---

0.125

* Minor fixes

---

0.124

* More experiments with mysql user creation

---

0.123

* Testing mysql user creation option

---

0.122

* Pre-release version, nextcloud auto-install not working

---

0.121

* Experimenting with database setup for nextcloud

---

0.120

* Fix preparenextcloud.sh script

---

0.119

* Fix nginx proxy to nextcloud

---

0.118

* Update nextcloud pot version
* Fixups for various copied-in config files and preparenextcloud.sh script

---

0.117

* Update nextcloud pot version

---

0.116

* Fix logic for nextcloud installation
* Copy-in separate nextcloud config.php files

---

0.115

* Combine host:port for mysql server in nextcloud config.php
* Eliminate dbport from config

---

0.114

* Fixups to nextcloud config.php using input from sample file
* Try using port 3306 instead of 33306

---

0.113

* Fix preparenextcloud.sh script
* Update documentation to reflect manually running preparenextcloud.sh

---

0.112

* Fix custom nextcloud config.php

---

0.111

* Update pot image versions

---

0.110

* Set vagrant variables to avoid dependency issues
* VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 on commands

---

0.109

* Patch all pot scripts from master
* Update pot image versions

---

0.108

* Brain derp, fixed common.sh
* Pull hotfix from the minio-sampler repo

---

0.107

* Add working common.sh for pot
* remove on pot version 0.15.4

---

0.106

* New nextcloud version

---

0.105

* New mariadb version

---

0.104

* Bump packbox step image size to 40gb

---

0.103

* Fix database setup script host wildcard

---

0.102

* enable ngx_stream_module

---

0.101

* nginx-full for stream functionality
* add mysql proxy to nginx

---

0.100

* Experimenting with pf.conf changes

---

0.99

* Undoing POT_EXTRA_EXTIF, doesn't help

---

0.98

* Change nomad client ip

---

0.97

* Trying POT_EXTRA_EXTIF option

---

0.96

* Port forward needed to be moved back to minio1
* revised pf.conf again, no nat

---

0.95

* Fixing missed updates 

---

0.94

* Switch nomad client to use vlan under untrusted (vtnet0)
* Adjust pf.conf

---

0.93

* Exposing minio and mysql on public IP for nomad jail access
* Networking issues between nomad jail and jailnet vlan with pot images

---

0.92

* Previous changes removed, makes everything slower
* pf.conf still not right

---

0.91

* Adding additional virtualbox settings to Vagrantfile

---

0.90

* Nomad client back on first server
* Nextcloud back on first server
* New pf.conf

---

0.89

* New approach with nomad client on minio2
* Nextcloud instance will run from minio2

---

0.88

* Adding back second set ssh port forwards
* Adjusting nomad client.hcl
* Adjusting nextcloud trusted hosts to IP addresses only

---

0.87

* Commenting out ssh service check due to timing problems

---

0.86

* Remove intnet option, ssh times out too often
* Add back hwvirtex

---

0.85

* Fix ssh ports

---

0.84

* Trimming down Vagrantfile
* Removing double ssh port forwards

---

0.83

* Adjusting Vagrantfile for various options

---

0.82

* Adjust nomad client.hcl
* Adjust nomad job

---

0.81

* adjustments to nextcloud and accessing minio or mysql
* another pf.conf setup
* remove second vlan on minio1

---

0.80

* Sysctl tweaks
* Adjust resolv.conf again
* Adjusting minio1 pf.conf

---

0.79

* Add back pf.conf
* Adjust nginx parameters for nextcloud
* Update nomad client config

---

0.78

* Bump nextcloud version

---

0.77

* Bump nextcloud version

---

0.76

* Bump nextcloud version

---

0.75

* Bump nextcloud version

---

0.74

* Initiating minio using direct IP

---

0.73

* Disabling dhclient.conf entry
* Removing the disabling of zpool features, carry over from 13.0

---

0.72

* Adding back internal nameserver, nomad pot jails not getting dns
* Disable pf for testing

---

0.71

* Bump nextcloud version

---

0.70

* Bump nextcloud version

---

0.69

* Bump nextcloud version

---

0.68

* dhclient.conf changes applied to vtnet0

---

0.67

* Remove IP restrictions on mysql user created for nextcloud
* Add only minio1 to prometheus minio job
* Reload prometheus instead of restart

---

0.66

* Bump beast-of-argh version for minio dashboard fixes
* Fix issues with nextcloud nomad job file

---

0.65

* Bump nextcloud version
* Re-order ansible vars
* Change nginx config for nextcloud proxy_pass

---

0.64

* Bump beast-of-argh version (not logged in prior commit)

---

0.63

* Remove restarts from nomad job to allow nextcloud install to finish

---

0.62

* Bump consul, nomad, traefik, beast-of-argh versions

---

0.61

* Bump nextcloud version

---

0.60

* Adjusting nomad restart timing
* Re-order ansible variables for nextcloud

---

0.59

* Bump nextcloud version
* Adjust nomad job to copy-in rootca.crt from minio self-signed setup

---

0.58

* Remove vlan from minio2
* Add simple pf.conf
* Prometheus won't get stats from minio2 for this example due to network issues
* Bump nextcloud image version

---

0.57

* Add vlan interface to minio2

---

0.56

* Double-quote nextcloud version in vars due to error (testing)

---

0.55

* Make sure minio stats are public for prometheus
* Preload the nextcloud pot image

---

0.54

* Disabling pf again
* Adjust nomad job file

---

0.53

* Bump nextcloud version

---

0.52

* Fix typo for mysql in prometheus monitoring

---

0.51

* Add minio hosts and mariadb to beast prometheus monitoring

---

0.50

* Added NETWORK-DESIGN.md

---

0.49

* Remove restarts from nextcloud nomad job, needs to install software and nomad keep restarts
* Fix bugs with wrong traefik IP to monitor

---

0.48

* Updating interface name to clone for pot jails to use vlan interface jailnet

---

0.47

* Fixing typo in jailnet vlan IP

---

0.46

* Switching to vlans for jail network

---

0.45

* Updates to Vagrantfile, attempting static routes

---

0.44

* Add natdnshostresolver1 value to Vagrantfile to fix jail DNS resolution issues

---

0.43

* Remove pf.conf from ansible setup for now
* Add sysctl values

---

0.42

* Disable starting pf for testing purposes, as hanging everything

---

0.41

* Experimenting with pf.conf setup, adding only at the end to ensure setup works
* Adjust /etc/resolv.conf again

---

0.40

* Overwrite /etc/resolv.conf with nameserver (testing) instead of append which introduces blank line

---

0.39

* Minor adjustments to reverse proxy
* Jails not getting DNS resolution for some reason

---

0.38

* Bump nextcloud image version

---

0.37

* Fix preparedatabase.sh script
* Update nextcloud version

---

0.36

* Remove trailing whitespace
* Remove tab characters

---

0.35

* Update README

---

0.34

* Add preparedatabase.sh script to ansible steps

---

0.33

* Remove nomad-client from minio2, only run nomad jobs on minio1
* Remove unnecessary ZFS datasets from minio2

---

0.32

* Remove host constraint for nomad job
* Bump nomad-server image version

---

0.31

* Cosmetic code fixes

---

0.30

* Additional hotfixes

---

0.29

* Bug fixes, prepare db and nextcloud not copied over

---

0.28

* Configure for nextcloud

---

0.27

* Fix nginx reverse proxy setup

---

0.26

* Patch pot common.sh
* because https://github.com/bsdpot/pot/commit/f033266a26ecd144dc047bb7f35929112407dfc0

---

0.25

* Version bump on consul image

---

0.24

* Split detailed install steps to own document

---

0.23

* Fix pot.conf
* Disable coredumps
* enable sysctl values for jails to allow ping

---

0.22

* Add strategic continues

---

0.21

* Update README some more

---

0.20

* Update README

---

0.19

* Update README with increased server specs
* Update consul pot image version with optional PEERS

---

0.18

* Fixed JSON formatting for consul agent.json

---

0.17

* Working cli minio bucket setup

---

0.16

* Trying different setup with minio commands for insecure flag

---

0.15

* Minio alias set, bucket creation, remove config host add

---

0.14

* Fixing minio for cli config

---

0.13

* Updating README
* Changing IP addresses, leaving vtnet1 unnamed, removing untrusted name, bugfixing IP issues

---

0.12

* Adjust IP addresses for testing purposes
* Update ports, update README

---

0.11

* Add more nginx workers
* Fix jail IP address subnet typo

---

0.10

* Add missing port forwards, update nginx config

---

0.9

* Update README
* Formatting, allowing long lines

---

0.8

* Increment added port forward by one to not clash with minio2

---

0.7

* Update README for number of cores and memory set for virtual machines
* Update nginx.conf to do reverse proxy to different services (testing required)
* Update vagrant port forwards

---

0.6

* Cleanup networking for .2 and .3 IP addresses

---

0.5

* Fix misnamed variable

---

0.4

* vtnet1 is actually untrusted interface
* formatting and indentation fixes

---

0.3

* Fix paths for consul configuration
* Adjust ERRATA file for /etc/vbox warning
* Adjust ansible for "scp_if_ssh = True"
* vtnet1 not vtnet0 for host interface pot jails associate with

---

0.2

* Trim to 2 hosts
* Add consul, nomad, traefik
* Add beast-of-argh
* Add nomad job for nextcloud

---

0.1

* First bash at minio-sampler
