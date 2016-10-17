class precip::phpmemcacheadmin {  
  vcsrepo { "/vagrant/util/phpmemcacheadmin":
    ensure    => latest,
    provider  => git,
    require   => Package["git"],
    source    => "https://github.com/hgschmie/phpmemcacheadmin.git",
    revision  => 'master'
  }

  file { "/vagrant/util/phpmemcacheadmin/Config/Memcache.php":
    content   => template('precip/phpmemcacheadmin.conf.erb'),
    require   => Vcsrepo['/vagrant/util/phpmemcacheadmin']
  }
  
  file {"/tmp/phpmemcacheadmin":
    ensure =>'directory',
    owner => 'www-data',
    group => 'www-data',
    mode => '0775',
  }
}
