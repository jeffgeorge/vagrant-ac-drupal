class precip {
  
  # ~magic incantations~ to ensure apt-get update runs before any package is installed
  Exec["apt_update"] -> Package <| |>
  
  class { 'apt': }
  
  # Grab some helpful base packages
  package {[
    "ntp",
    "htop",
    "curl",
    "wget",
    "bzip2",
    "git",
    "openssl",
    "imagemagick",
    "vim",
    "g++",
    ]:
    ensure => present,
  }

  # Install a variety of Language Packs
  package {[
    "language-pack-de",
    "language-pack-en",
    "language-pack-es",
    "language-pack-fr",
    "language-pack-it",
    "language-pack-ja",
    "language-pack-nl",
    "language-pack-nn",
    "language-pack-pt",
    "language-pack-ru",
    "language-pack-sv",
    "language-pack-zh-hans",
    "language-pack-zh-hant",
    ]:
    ensure => present,
  }

  # Grab some gems.
  # @TODO: Convert to a bundle? Define a bundle path in config.rb and bundle install each of those?
  package {[
    "compass",
    "breakpoint",
    "sass",
    "susy",
    ]:
    ensure => 'installed',
    provider => 'gem',
  }

  # Make our log directory
  file {"/vagrant/log": ensure => "directory", }

  # Fix the timezone with a symlink
  file { '/etc/localtime':
    ensure => "link",
    force => "true",
    target => "/usr/share/zoneinfo/US/Eastern",
  }

  # Bring in Mailcatcher, because Mailcatcher is neat.
  class { 'mailcatcher': 
    require => Package['g++']
  }

  # WKhtmltopdf using jlondon/wkhtmltox module
  # as described here: https://forge.puppetlabs.com/jlondon/wkhtmltox
  class { 'wkhtmltox':
    ensure => present,
  }

  # Kick off the rest of our manifests
  include 'precip::php'
  include 'precip::httpd'
  include 'precip::database'
  
  file { "/etc/init/restart_services_once_mounted.conf":
    content => template("precip/restart_services_once_mounted.conf.erb"),
    ensure  => 'file',
    mode    => '0644',
  }
}
