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
}