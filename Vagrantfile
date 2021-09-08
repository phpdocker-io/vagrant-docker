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

  # Provision the machine with ansible. This requires you to have ansible installed on your host
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbook.yaml"
  end

  vm_cpus = 1
  vm_mem = 4096

  config.trigger.before :provision, type: :action do |t|
    t.warn = "This runs on vagrant provision, but not on initial vagrant up or vagrant reload --provision."
  end

  config_file = 'config.yaml'
  if File.exists?(config_file)
      config_options = YAML.load_file(config_file)

      if config_options.key?('services')
          config_options['services'].each do |service|
            if service.key?('gateway')
                config.trigger.before :"Vagrant::Action::Builtin::Provision", type: :action do |trigger|
                  trigger.run = { inline: "make init-service-hostnames -e SITE_HOST=" + service['gateway']['hostname'] }
                end
            end
          end
      end

      if config_options.key?('vm')
        vm_options = config_options['vm']
        if vm_options.key?('cpus')
            vm_cpus = vm_options['cpus']
        end
        if vm_options.key?('mem')
            vm_mem = vm_options['mem']
        end
      end
  end

  # VM configuration
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.cpus = vm_cpus
    vb.memory = vm_mem
  end
end
