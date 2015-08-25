#!/usr/bin/env ruby

#
# TODO:
#   Setup DNS records for each created host in the cluster
#   Setup DNS domain for the domain if it does not exist
#   Create ssh key's via API if they don't exist
#   Add consistent error handling and usage printing
#   Add error handling for missing DIGITALOCEAN_TOKEN
#
# Setup:
#
#   $ gem install droplet_kit
#   $ chmod +x armada.rb
#   $ mv armada.rb ~/bin (optional)
#   $ export DIGITALOCEAN_TOKEN=YOUR_TOKEN_HERE
#   $ armada.rb <options> (list|deploy|sink) <arguments>
#
# Examples:
#
#   List parameter options from DigitalOcean
#
#   $ armada list sizes
#   $ armada list regions
#   $ armada list images
#   $ armada list ssh_keys
#
#   Create and bootup a group of droplets to your specifications
#
#   $ armada -v -n 5 -s 512mb -i freebsd-10-1-x64 -r nyc3 \
#     -k 75:5d:29:38:a7:8e:c3:18:92:c3:7b:3e:b1:c2:a7:11 -d example.com deploy hadooped
#
#   Created droplet hadooped0.example.com
#   Created droplet hadooped1.example.com
#   Created droplet hadooped2.example.com
#   Created droplet hadooped3.example.com
#   Created droplet hadooped4.example.com
#   2015-08-25 14:32:31 -0400: Waiting for fleet to sail...
#   2015-08-25 14:32:39 -0400: Waiting for fleet to sail...
#   2015-08-25 14:32:46 -0400: Waiting for fleet to sail...
#   2015-08-25 14:32:53 -0400: Waiting for fleet to sail...
#   2015-08-25 14:33:01 -0400: Waiting for fleet to sail...
#   2015-08-25 14:33:09 -0400: Waiting for fleet to sail...
#   2015-08-25 14:33:17 -0400: Waiting for fleet to sail...
#   2015-08-25 14:33:25 -0400: Waiting for fleet to sail...
#   2015-08-25 14:33:32 -0400: Waiting for fleet to sail...
#   Deployed hadooped0.example.com to 45.55.92.47 DropletID: 6830389
#   Deployed hadooped1.example.com to 104.236.12.69 DropletID: 6830390
#   Deployed hadooped2.example.com to 104.131.99.155 DropletID: 6830391
#   Deployed hadooped3.example.com to 104.236.26.177 DropletID: 6830393
#   Deployed hadooped4.example.com to 45.55.88.16 DropletID: 6830394
#
#   Created droplets are enumerated with name and domain like:
#
#   hadooped1.example.com
#   hadooped2.example.com
#   hadooped3.example.com
#   hadooped4.example.com
#   hadooped5.example.com
#
#   $ armada list droplets | grep hadooped
#
#   Destroy any droplets with hostnames matching a given regular expression
#
#   $ armada sink ^hadooped
#
#   Destroying droplet: 6830370 (hadooped0.example.com)
#   Destroying droplet: 6830371 (hadooped1.example.com)
#   Destroying droplet: 6830389 (hadooped0.example.com)
#   Destroying droplet: 6830390 (hadooped1.example.com)
#   Destroying droplet: 6830391 (hadooped2.example.com)
#   Destroying droplet: 6830393 (hadooped3.example.com)
#   Destroying droplet: 6830394 (hadooped4.example.com)
#

require 'optparse'
require 'droplet_kit'

class Armada

  def initialize(token, options)
    self.options = options
    self.token = token
  end

  def deploy(fleet_name)
    number = options[:number].to_i

    droplet_ids = number.times.map do |n|
      hostname = [
        "#{fleet_name}#{n}",
        options[:domain]
      ].compact.join('.')

      droplet = DropletKit::Droplet.new(
        name: hostname,
        region: options[:region],
        image: options[:image],
        size: options[:size],
        ssh_keys: options[:ssh_keys],
        backups: false,
        ipv6: false,
        private_networking: true,
      )
      created = client.droplets.create(droplet)

      if created.to_s.match /forbidden/
        STDERR.puts JSON.parse(created)['message']
        nil
      else
        verbose_output("Created droplet #{created.name}")
        created.id
      end
    end.compact

    while droplets_booting?(droplet_ids) do
      verbose_output("#{Time.now}: Waiting for fleet to sail...")
      sleep(5)
    end

    droplet_ids.each do |id|
      droplet = client.droplets.find(id: id)

      public_ip = droplet.networks.first.select do |netif|
        netif.type == 'public'
      end.first.ip_address

      puts "Deployed #{droplet.name} to #{public_ip} DropletID: #{id}"
    end
  end

  def list(resource)
    case resource.to_sym
    when :droplets then client.droplets.all.map(&:name)
    when :sizes then client.sizes.all.map(&:slug)
    when :regions then client.regions.all.map(&:slug)
    when :images then client.images.all.select(&:public).map(&:slug)
    when :ssh_keys then client.ssh_keys.all.map(&:fingerprint)
    else STDERR.puts "Invalid resource" and exit
    end
  end

  def sink(regexp)
    client.droplets.all.select { |droplet| droplet.name.match(regexp) }.each do |droplet|
      puts "Destroying droplet: #{droplet.id} (#{droplet.name})"
      client.droplets.delete(id: droplet.id)
    end
  end

  private

  attr_accessor :options, :token

  def client
    @client ||= DropletKit::Client.new(access_token: token)
  end

  def droplets_booting?(droplet_ids)
    droplet_ids.select {|id| client.droplets.find(id: id).status != 'active'}.any?
  end

  def verbose_output(message)
    puts message if options[:verbose]
  end

end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: armada.rb <options> (list|deploy|sink) <arguments>"
  opts.on('-n N', '--number N', Numeric, 'Number of droplets to create') { |opt| options[:number] = opt }
  opts.on('-s N', '--size N', 'Size of droplets to create') { |opt| options[:size] = opt }
  opts.on('-i N', '--image N', 'Image of droplets to create') { |opt| options[:image] = opt }
  opts.on('-r N', '--region N', 'Region to create droplets in') { |opt| options[:region] = opt }
  opts.on('-k X,Y,Z', '--ssh-keys X,Y,Z', Array, 'Comma delimited public key fingerprints') { |opt| options[:ssh_keys] = opt }
  opts.on('-d N', '--domain N', 'Domain name for droplet hostnames') { |opt| options[:domain] = opt }
  opts.on('-v', '--verbose', 'Display extra info on what is happening') { |opt| options[:verbose] = true }
  opts.on('-h', '--help', 'Display this screen' ) { puts opts; exit }
end

optparse.parse!

if ARGV.count < 2
  STDERR.puts "Usage: armada (options) <command> <arguments>"
  exit 1
end

token = ENV['DIGITALOCEAN_TOKEN']
armada = Armada.new(token, options)

case ARGV[0]
  when 'list' then puts armada.list(ARGV[1])
  when 'deploy' then armada.deploy(ARGV[1])
  when 'sink' then armada.sink(ARGV[1])
  else STDERR.puts 'Unknown command'
end
