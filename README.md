# Introduction
`minio-sampler` (aka `minsampler`) borrows heavily from [potman](https://github.com/bsdpot/potman), [minio-incinerator](https://github.com/bretton/minio-incinerator/), `clusterfurnace` and `cephsmelter` to build a virtualbox minio cluster .

It is a sampler environment matching the HOWTO at [How To Set Up a Minio Cluster From Potluck, Complete With Nextcloud, Monitoring And Alerting](https://honeyguide.eu/posts/minio-beast-nextcloud/).

Do not run in production! 

This is a testing environment to show `minio` running on FreeBSD, with `consul`, `nomad`, and the Beast-of-Argh one-pot monitoring solution providing `prometheus`, `grafana`, `loki`, `alertmanager`, plus a `nextcloud` nomad image, configured to use `minio` S3 as file storage, and a `mariadb` pot image for the `nextcloud` database.

As of 2022-11-24 everything works EXCEPT automatic nextcloud install. You can evaluate minio and the monitoring systems in the meantime.

# Outline
This will bring up 2 minio servers:
* minio1 (8CPU, 8GB, 4 attached disks)
* minio2 (4CPU, 4GB, 4 attached disks)

# Requirements
The host computer running `minio-sampler` needs at least 16 CPU threads, 16GB memory, plus 50GB disk space, preferably high speed SSD. The setup takes an hour or so with packbox step included.

# Overview

## Quickstart
To create your own sampler, init the VMs:

    git clone https://github.com/bretton/minio-sampler.git
    cd minio-sampler

      (edit) config.ini and set ACCESSIP to a free IP on LAN, and set DISKSIZE

    export PATH=$(pwd)/bin:$PATH
    (optional: sudo chmod 777 /tmp)
    minsampler init mysample
    cd mysample
    minsampler packbox
    minsampler startvms
      vagrant ssh minio1
      OR
      open http://ACCESSIP
      ...
        ./preparenextcloud.sh  # not working
    ...
    minsampler status
    ...

## Stopping

    minsampler stopvms

## Destroying

    minsampler destroyvms

## Dependencies

`minio-sampler` requires
- ansible
- bash
- git
- packer
- vagrant
- virtualbox

# Installation and Operation

Please see [Detailed Install FreeBSD & Linux](DETAILED-INSTALL.md)

# Usage

    Usage: minsampler command [options]

    Commands:
        destroyvms  -- Destroy VMs
        help        -- Show usage
        init        -- Initialize new minio-sampler
        packbox     -- Create vm box image
        startvms    -- Start (and provision) VMs
        status      -- Show status
        stopvms     -- Stop VMs

## config.ini

### Access IP

A virtual interface is created with a free IP address from the LAN. You must provide this free IP address in `config.ini` in the `ACCESSIP` section.

Everything is accessible via frontend at `http::/ACCESSIP`

### Disk Sizes

Virtual disks are saved in the `minio-sampler` directory for the duration of running the program. 

Set the size of the virtual disks in `config.ini` in the `DISKSIZE` section. 

Input disk size in thousands of MB, where 10000 (MB) is the same as 10GB. 

To set a 2GB disk, use 2000. This is the default.

Do not add the metric M, or MB or GB! It won't work.

Eight (8) virtual drives will be created of this size, so ensure you have sufficient disk space!

A basic check is done to see if the input figures can be catered to, on running `minsampler init <name>`.

## Dashboards

The default dashboard with links to all the included tools is `http://ACCESSIP`. There is a default index pahe with links to the tools.

Where `https` is applicable, please accept the self-signed certificate. You might need to do this twice, even refresh the page, to get the minio dashboard.

### Minio

The Minio web interface is available via nginx reverse proxy at `https://ACCESSIP:19000` for the IP address set in ACCESSIP variable of `config.ini`.

Accept the self-signed certificate TWICE. First is for nginx, second minio. Remember, this is not a production-ready environment. 

Login with user `sampler` and `samplerpasswordislong` to access the dashboard.

You can now create a bucket and explore settings.

### Grafana

The Grafana web interface is available via nginx reverse proxy at `http://ACCESSIP:13000`. 

Login with username `admin` and password `sampler`.

### Prometheus

The Prometheus web interface is available via nginx reverse proxy at `http://ACCESSIP:19090` and no credentials.

### Alertmanager

The Alertmanager web interface is available via nginx reverse proxy at `http://ACCESSIP:19093` and no credentials.

### Consul

The Consul web interface is available nginx reverse proxy at `http://ACCESSIP:18500` and no credentials.

### Nomad

The Nomad web interface is available nginx reverse proxy at `http://ACCESSIP:14646` and no credentials.

### Traefik

The Traefik web interface is available nginx reverse proxy at `http://ACCESSIP:19002` and no credentials.

## Applications

### Nextcloud

There is a Nextcloud instance available at `https://ACCESSIP:10443`.

The admin username is `sampler` and password `sampler123`.

The automatic setup script is currently not working in this specialised setup.