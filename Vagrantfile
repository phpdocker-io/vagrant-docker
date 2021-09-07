# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"

  # Workaround for https://bugs.launchpad.net/bugs/1873506
  config.vm.box_version = "20210415.0.0"
  config.vm.box_check_update = false

  # Create a private network on your host that's accessible from the guest - this is useful if you need connections
  # back to your host from your guest
  # For instance, you might want to connect a xdebug session from your guest into your IDE
  config.vm.network "private_network", ip: "192.168.33.10"

  # We have an HTTP gateway via nginx. Open ports to it
  config.vm.network "forwarded_port", guest: 80,  host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"

  # Share the projects folder into vagrant's home for easy access
  config.vm.synced_folder "projects", "/home/vagrant/projects"

  # VM configuration
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.cpus = 1
    vb.memory = "4096"
  end

  # Provision the machine with ansible. This requires you to have ansible installed on your host
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbook.yaml"
  end

  # Load services file in order to correctly set any port mappings between vm and host
  services_file = 'services.yaml'
  if File.exists?(services_file)
      services = YAML.load_file(services_file)

      services['definitions'].each do |service|
        service['port_mappings'].each do |ports|
          config.vm.network "forwarded_port", guest: ports['guest'], host: ports['host'], host_ip: "127.0.0.1"
        end

        config.trigger.before [:provision] do |trigger|
          trigger.run = { inline: "make init-service-hostnames -e SITE_HOST=" + service['hostname'] }
        end
      end
  end
end
