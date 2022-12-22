# Virtualbox Network Design and FreeBSD with Jails

## Help, my jails have no DNS

When setting up FreeBSD hosts using Virtualbox and Vagrant, there is a recurring issue of jails not getting DNS resolution.

The cause is jail interfaces on vtnet1 not reaching the gateway 10.0.2.2 on vtnet0.

## Solution

Retain vtnet0 as gateway device, and add a vlan for another internal IP range, e.g. 10.200.1.0/24. Jails can be configured to use IP addresses in this range, rather than in the range for vtnet1.

Configure pot to use the vlan interface, and setup pf to do some extra steps.

Ensure the host /etc/resolv.conf has a working nameserver other than 10.0.2.3. This will carry through to the jails. 

You can use Google's at `8.8.8.8`, or Cloudflare at `1.1.1.1`, or Quad9 at `9.9.9.9` with

```
nameserver 8.8.8.8
```

## Example setup
```
vtnet0 (dhcp)
  10.0.2.15
  vlan: jailnet, 10.200.1.0/24
vtnet1 (static)
  10.100.1.3
vtnet2 (static)
  192.168.0.240
```
