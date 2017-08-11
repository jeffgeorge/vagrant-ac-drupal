# Pull in external config
require "json"
drupal_sites = {}
drupal_basepath = "sites"
internal_hosts = []
external_hosts = {}
packaging_mode = false
forward_ssh_agent = false
vm_name = "precip"
use_packaged_precip = false
rsync = false

# Determine if this is our first boot or not. 
# If there's a better way to figure this out we now have a single place to change.
first_boot = true
if File.file?('.vagrant/machines/default/virtualbox/action_provision')
  first_boot = false
end

# Determine if our config.rb exists or not, fail gracefully
if !File.file?('config.rb')
  abort("Error: 'config.rb' is missing. Please review README.md and config.rb-dist to create one.")
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

drupal_sites.each do |name, site|
  if site.has_key?("host")
    internal_hosts.push(site['host'])
  end
  if site.has_key?("aliases")
    internal_hosts.push(site['aliases'])
  end
end
internal_hosts.push("70.precip.vm")
internal_hosts.push("71.precip.vm")
internal_hosts = internal_hosts.flatten

# The actual Vagrant Configuration
Vagrant.configure(2) do |config|
  # Vagrant Box Address
  if use_packaged_precip == true
    # The pre-packaged and shrink-wrapped version of Precip
    config.vm.box = "clwdev/precip"
    config.vm.box_version = "2.0.0"
  else
    # The super-generic simple Ubuntu 16.04 base box (with Puppet)
    config.vm.box = "clwdev/precip-16.04-base"
    config.vm.box_version = "1.0.0"
  end

  # Basic network config.
  config.vm.network :private_network, ip: "10.0.0.11"
  config.vm.hostname = "precip.vm"
  config.hostsupdater.aliases = internal_hosts

  # Ensure users exist before we mount stuff
  config.useradd.users = {
    'www-data' => ['www-data'],
    'mysql' => nil,
    'vagrant' => ['vagrant','www-data'],
  }

  # Disabling vbguest is helpful in development
  # config.vbguest.auto_update = false

  # Forward your host's SSH Agent to the VM
  # Allows for key-based git repo authentication inside the box without copying keys
  config.ssh.forward_agent = forward_ssh_agent

  # Synced Folders
  if rsync
    # For large codebases, rsync is *far* more performant than NFS.
    config.vm.synced_folder drupal_basepath, "/srv/www", type: "rsync", rsync__exclude: [".git/", "*.sql", "db/", "**/sites/*/files"], owner: "vagrant", group: "www-data"
    # Vagrant's own rsync plugin is absurdly slow to sync, so use Gatling instead:
    # https://github.com/smerrill/vagrant-gatling-rsync
    # Configure the window for gatling to coalesce writes.
    if Vagrant.has_plugin?("vagrant-gatling-rsync")
      config.gatling.latency = 1
      config.gatling.time_format = "%H:%M:%S"
      # Automatically sync when machines with rsync folders come up.
      config.gatling.rsync_on_startup = true
    end
  elsif Vagrant::Util::Platform.windows?
    # Windows gets vboxsf, because it can't do nfs + bindfs
    config.vm.synced_folder drupal_basepath, "/srv/www", owner: "www-data", group: "www-data"
  else
    # Everybody else gets nfs + bindfs, for better small-file read perf
    config.vm.synced_folder drupal_basepath, "/nfs-www", type: "nfs"
    config.bindfs.bind_folder "/nfs-www", "/srv/www", user: "vagrant", group: "www-data", chown_ignore: true, chgrp_ignore: true, perms: "u=rwx:g=rwx:o=rx"
  end

  # MySQL now uses the vagrant-persistent-storage module.
  # Same concept as before & same benefits, but with the added bonus of being a native filesystem instead of a share.
  config.persistent_storage.enabled = true
  config.persistent_storage.location = "mysql.vdi"
  config.persistent_storage.size = 32768
  config.persistent_storage.mountname = 'mysql'
  config.persistent_storage.filesystem = 'ext4'
  config.persistent_storage.mountpoint = '/var/lib/mysql'
  
  # Want to mount your *old* MySQL dir so you can copy your old files over? 
  # Uncomment this and run: vagrant reload && vagrant ssh -c "sudo bash /vagrant/shell/migrate-db.sh"
  #config.vm.synced_folder "mysql", "/var/lib/mysql-old", owner: "mysql", group: "mysql"
  
  # Mount the log directory straight at /var/log/apache2, so PimpMyLog can access it
  config.vm.synced_folder "log", "/var/log/apache2", owner: "www-data", group: "www-data"
  
  # Mount the gitignored puppet/modules directory, for caching
  config.vm.synced_folder "puppet/modules", "/etc/puppet/modules"

  # Configure the VM. Tweak as needed
  configured = -1
  config.vm.provider :virtualbox do |vb|
    # Provide a unique name for this virtual machine
    vb.customize ["modifyvm", :id, "--name", vm_name]
    # IOAPIC is needed for a 64bit host for multiple cures
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    # Use ICH9 for performance
    vb.customize ["modifyvm", :id, "--chipset", "ich9"]
    # Use kvm (instead of legacy) as the paravirtprovider
    # on Linux guests for performance
    # https://github.com/geerlingguy/drupal-vm/issues/212
    vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
    # Am79C973 is shown to have the best performance http://kylebush.github.io/Improve-VirtualBox-Vagrant-Network-IO-Performance/
    vb.customize ["modifyvm", :id, "--nictype1", "Am79C973"]
    vb.customize ["modifyvm", :id, "--nictype2", "Am79C973"]
    # Defer DNS resolution to the host for performance
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    # Prevent Virtualbox status errors about vram
    vb.customize ["modifyvm", :id, "--vram", "10"]
    # Prevent a time drift of more than a minute from the host
    vb.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 60000]
    # Set reserved memory at 2GB, as we've never seen it actively use more than ~1.5G
    vb.customize ["modifyvm", :id, "--memory", 2048]
    # Give half of cpu cores as the host (if more than 1), otherwise leave as default
    # In our testing this produced the best results. Adapted from https://github.com/rdsubhas/vagrant-faster
    host = RbConfig::CONFIG['host_os']
    cpus = -1
    if host =~ /darwin/
      cpus = `sysctl -n hw.ncpu`.to_i
      mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024
    elsif host =~ /linux/
      cpus = `nproc`.to_i
    elsif host =~ /mswin|mingw|cygwin/
      cpus = `wmic cpu Get NumberOfCores`.split[1].to_i
    end
    cpus = cpus / 2 if cpus > 1
    if cpus > 0
      vb.customize ["modifyvm", :id, "--cpus", cpus]
      # Suppress CPU Setting Noise, uncomment for debug purposes
      # if configured < 1
      #   puts "CPUs set to: #{cpus}"
      # end
    end
    # Allow Windows Hosts to create symlinks inside shared folders
    if Vagrant::Util::Platform.windows?
      vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
    end
    configured = 1
  end

  # Set up and use puppet-librarian inside the box to get all our Puppet Modules
  config.vm.provision "shell", path: "shell/librarian.sh"
  
  # Hand off to puppet
  config.vm.provision :puppet, :options => ["--disable_warnings deprecations"] do |puppet|
    puppet.environment_path = "puppet/environments"
    puppet.environment = "vm"
    puppet.hiera_config_path = "puppet/hiera.yaml"
  
    # some facts
    puppet.facter = {
      "drupal_sites_path" => Dir.pwd + "/" + drupal_basepath,
      "drupal_siteinfo" => drupal_sites.to_json,
      "drupal_hosts" => internal_hosts.to_json,
      "external_hosts" => external_hosts.to_json,
      "first_boot" => first_boot,
      "packaging_mode" => packaging_mode,
    }
  end
  
  if File.file?('shell/custom.sh')
    # Run any Extra stuff you may need
    config.vm.provision "shell", path: "shell/custom.sh", privileged: false
  end
end
