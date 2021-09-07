# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"

  # Workaround for https://bugs.launchpad.net/bugs/1873506
  config.vm.box_version = "20210415.0.0"
  config.vm.box_check_update = false

  # Create a private network on your host that's accessible from the guest. Reasons:
  #  * You don't need port forwarding, if a port is active on your VM it'll be accessible on this IP from your host
  #  * You can connect back from your guest VM into your host, for instance if you need Xdebug on the guest sending
  #    data to into your IDE for a debug session
  config.vm.network "private_network", ip: "192.168.33.10"

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
        config.trigger.before [:provision] do |trigger|
          trigger.run = { inline: "make init-service-hostnames -e SITE_HOST=" + service['gateway']['hostname'] }
        end
      end
  end
end
