class precip::database {
  file {"/etc/mysql":
    owner => "mysql",
    group => "mysql",
    mode => '0755',
    ensure => "directory",
  }  
  
  # Debian-based distros are weird, and need their own extra conf file
  file { "/etc/mysql/debian.cnf":
    content => template("precip/debian.cnf"),
    ensure  => 'file',
    mode    => '0644',
    require => File['/etc/mysql'],
  }
  
  # Define the Percona apt repo
  apt::source { 'Percona':
    location   => 'http://repo.percona.com/apt',
    repos      => 'main',
    key        => {
      'id'     => '430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A',
      'server' => 'keys.gnupg.net',
    },
  }
  
  class { 'mysql::client':
    package_name => 'percona-server-client-5.5',
    package_ensure => 'latest',
    require => [
      Apt::Source['Percona'],
    ]
  }
  
  class { 'mysql::server':
    package_name => 'percona-server-server-5.5',
    package_ensure => 'latest',
    override_options => { 
      'mysqld' => { 
        'bind-address' => '0.0.0.0',
        'log_error' => '/vagrant/log/mysql_error.log'
      },
      'mysqld_safe' => {
        'log_error' => '/vagrant/log/mysql_error.log'
      }
    },
    require => [
      Apt::Source['Percona'],
    ]
  }

  mysql_user { 'root@%': 
    ensure => 'present',
    password_hash => mysql_password('precip'),
    subscribe    =>  Service['mysqld']
  }

  mysql_grant { 'root@%/*.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['ALL'],
    table      => "*.*",
    user       => 'root@%',
    require    => Mysql_user['root@%'],
  }
  
  # MySQL isn't *really* available to all hosts until you restart it. 
  # So we need to restart it on *first boot only*.
  if str2bool("$first_boot") {
    exec { "restart-mysqld-after-grant":
      path => ["/bin", "/sbin", "/usr/bin", "/usr/sbin/"],
      command => "service mysql restart",
      require => Mysql_grant["root@%/*.*"],
    }
  }
}