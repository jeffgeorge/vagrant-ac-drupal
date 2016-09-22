class precip::pimpmylog {  
  vcsrepo { "/var/www/pimpmylog":
    ensure    => latest,
    provider  => git,
    require   => Package["git"],
    source    => "https://github.com/potsky/PimpMyLog.git",
    revision  => 'master'
  }
  
  file { "/var/www/pimpmylog": 
    ensure    => directory,
    mode      => 0777
  }
  
  # Set up the vhost
  apache::vhost { "pml.precip.vm":
    docroot => "/var/www/pimpmylog",
    manage_docroot => false,
    port => '80',
    directories => [{
        path => "/var/www/pimpmylog",
        allow_override => ['All',],
    }],
    access_log => false,
        logroot => "/vagrant/log",
  }
}