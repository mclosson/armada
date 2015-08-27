# armada
Multi-server deployment automation for the DigitalOcean API

Armada is a tool to quickly create and boot multiple servers matching a
common criteria on DigitalOcean without significant overhead from
learning and configuring a larger automation framework.

## TODO

* Setup DNS records for each created host in the cluster
* Setup DNS domain for the domain if it does not exist
* Create ssh key's via API if they don't exist
* Add consistent error handling and usage printing
* Add error handling for missing DIGITALOCEAN_TOKEN

## Limitations

DigitalOcean currently only lets you create 25 droplets on your account
without manually requesting this limit be raised via their ticketing
system.  Trying to create more than 25 droplets will truncate any
droplets over this limit unless DigitalOcean modifies your account.

## Setup

```sh
$ gem install droplet_kit
$ curl -O https://raw.githubusercontent.com/mclosson/armada/master/armada.rb
(Read armada.rb so you know what it does, its not much code at all)
$ chmod +x armada.rb
$ mv armada.rb ~/bin/armada (optional)
$ export DIGITALOCEAN_TOKEN=YOUR_TOKEN_HERE
$ armada <options> (list|deploy|sink) <arguments>
```

## Examples

### Get help menu

```sh
$ armada.rb -h
Usage: armada.rb <options> (list|deploy|sink) <arguments>
    -n, --number N                   Number of droplets to create
    -s, --size N                     Size of droplets to create
    -i, --image N                    Image of droplets to create
    -r, --region N                   Region to create droplets in
    -k, --ssh-keys X,Y,Z             Comma delimited public key fingerprints
    -d, --domain N                   Domain name for droplet hostnames
    -v, --verbose                    Display extra info on what is happening
    -h, --help                       Display this screen
```

### List parameter options from DigitalOcean

```sh
$ armada list sizes
$ armada list regions
$ armada list images
$ armada list ssh_keys
```

### Create and bootup a group of droplets to your specifications

```sh
$ armada -v -n 5 -s 512mb -i freebsd-10-1-x64 -r nyc3 \
  -k 75:5d:29:38:a7:8e:c3:18:92:c3:7b:3e:b1:c2:a7:11 -d example.com deploy hadooped
  
Created droplet hadooped0.example.com
Created droplet hadooped1.example.com
Created droplet hadooped2.example.com
Created droplet hadooped3.example.com
Created droplet hadooped4.example.com
2015-08-25 14:32:31 -0400: Waiting for fleet to sail...
2015-08-25 14:32:39 -0400: Waiting for fleet to sail...
2015-08-25 14:32:46 -0400: Waiting for fleet to sail...
2015-08-25 14:32:53 -0400: Waiting for fleet to sail...
2015-08-25 14:33:01 -0400: Waiting for fleet to sail...
2015-08-25 14:33:09 -0400: Waiting for fleet to sail...
2015-08-25 14:33:17 -0400: Waiting for fleet to sail...
2015-08-25 14:33:25 -0400: Waiting for fleet to sail...
2015-08-25 14:33:32 -0400: Waiting for fleet to sail...
Deployed hadooped0.example.com to 45.55.92.47 DropletID: 6830389
Deployed hadooped1.example.com to 104.236.12.69 DropletID: 6830390
Deployed hadooped2.example.com to 104.131.99.155 DropletID: 6830391
Deployed hadooped3.example.com to 104.236.26.177 DropletID: 6830393
Deployed hadooped4.example.com to 45.55.88.16 DropletID: 6830394
```

### Created droplets are enumerated with name and domain like:

```sh
$ armada list droplets | grep hadooped

hadooped0.example.com
hadooped1.example.com
hadooped2.example.com
hadooped3.example.com
hadooped4.example.com
```

### Destroy droplets whose hostnames match a given regular expression

```sh
$ armada sink ^hadooped

Destroying droplet: 6830389 (hadooped0.example.com)
Destroying droplet: 6830390 (hadooped1.example.com)
Destroying droplet: 6830391 (hadooped2.example.com)
Destroying droplet: 6830393 (hadooped3.example.com)
Destroying droplet: 6830394 (hadooped4.example.com)
```
