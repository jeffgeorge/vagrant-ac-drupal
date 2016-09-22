# Ensure we've got some Helpful Plugins
%x(vagrant plugin install vagrant-vbguest) unless Vagrant.has_plugin?('vagrant-vbguest')
%x(vagrant plugin install vagrant-hostsupdater) unless Vagrant.has_plugin?('vagrant-hostsupdater')
%x(vagrant plugin install vagrant-useradd) unless Vagrant.has_plugin?('vagrant-useradd')
%x(vagrant plugin install vagrant-bindfs) unless Vagrant.has_plugin?('vagrant-bindfs')

# Pull in external config
require "json"
drupal_sites = ""
drupal_basepath = "sites"

# Determine if this is our first boot or not. 
# If there's a better way to figure this out we now have a single place to change.
first_boot = true
if File.file?('.vagrant/machines/default/virtualbox/action_provision')
  first_boot = false
end

ext_config = File.read 'config.rb'
eval ext_config

# Clone repos if necessary
drupal_sites.each do |name, site|
  if site.has_key?("git_url") && site.has_key?("git_dir") && !Dir.exists?( Dir.pwd + "/" + drupal_basepath + "/" + site['git_dir'] + "/.git")
    puts "No Git Clone found for \"#{name}\""
    git_cmd = "git clone #{site['git_url']} #{drupal_basepath}/#{site['git_dir']}"
    %x{ #{git_cmd} }
  end
end

# The actual Vagrant Configuration
Vagrant.configure(2) do |config|
  # Vagrant Box Address
  # This is a happy base box from PuppetLabs
  config.vm.box = "puppetlabs/ubuntu-14.04-64-puppet"
  # Pin to 1.0.0 for perf reasons
  config.vm.box_version = "1.0.0"

  # Basic network config.
  config.vm.network :private_network, ip: "10.0.0.11"
  config.vm.hostname = "precip.vm"
  config.hostsupdater.aliases = drupal_sites.collect { |k,v| v["host"] }.concat(drupal_sites.collect { |k,v| v["aliases"] }.flatten.select! { |x| !x.nil? })
  config.hostsupdater.aliases.push("pml.precip.vm") 

  # Ensure users exist before we mount stuff
  config.useradd.users = {
    'www-data' => ['www-data'],
    'mysql' => nil
  }

  # Disabling vbguest is helpful in development
  # config.vbguest.auto_update = false

  # Synced Folders
  if Vagrant::Util::Platform.windows?
    # Windows gets vboxsf for everything. Sorry Windows!
    config.vm.synced_folder drupal_basepath, "/srv/www", owner: "www-data", group: "www-data"
    config.vm.synced_folder "mysql", "/var/lib/mysql", owner: "mysql", group: "mysql"
  else
    # Everybody else gets nfs + bindfs for their Apache folders
    config.vm.synced_folder drupal_basepath, "/nfs-www", type: "nfs"
    config.bindfs.bind_folder "/nfs-www", "/srv/www", user: "www-data", group: "www-data"
    
    if first_boot
      # MySQL has to be mounted with vboxsf initially, because MySQL Is Terrible
      config.vm.synced_folder "mysql", "/var/lib/mysql", owner: "mysql", group: "mysql"
    else 
      # Once MySQL is installed during initial provisioning we can re-mount with nfs + bindfs
      config.vm.synced_folder "mysql", "/nfs-sql", type: "nfs"
      config.bindfs.bind_folder "/nfs-sql", "/var/lib/mysql", user: "mysql", group: "mysql"
    end
  end
  
  # Mount the gitignored puppet/modules directory, for caching
  config.vm.synced_folder "puppet/modules", "/etc/puppet/modules"

  # Throw more resources at the VM. Tweak as needed
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2560", "--ioapic", "on", "--cpus", "2", "--chipset", "ich9", "--name", "precip"]
  end

  # Fix the harmless "stdin: is not a tty" issue once and for all
  config.vm.provision "fix-no-tty", type: "shell" do |s|
      s.privileged = false
      s.inline = "sudo sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile"
  end

  # Set up and use puppet-librarian inside the box to get all our Puppet Modules
  config.vm.provision "shell", path: "shell/librarian.sh"
  
  # Hand off to puppet
  config.vm.provision :puppet, :options => [""] do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.manifest_file  = "site.pp"
    puppet.hiera_config_path = "puppet/hiera.yaml"
  
    # some facts
    puppet.facter = {
      "drupal_sites_path" => Dir.pwd + "/" + drupal_basepath,
      "drupal_siteinfo" => drupal_sites.to_json,
      "drupal_hosts" => drupal_sites.collect { |k,v| v["host"] }.concat(drupal_sites.collect { |k,v| v["aliases"] }.flatten.select! { |x| !x.nil? }).to_json,
      "first_boot" => first_boot,
    }
  end
end
