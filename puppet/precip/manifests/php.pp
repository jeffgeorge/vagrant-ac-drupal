class precip::php {
  
  ::apt::key { '14AA40EC0831756756D7F66C4F4EA0AAE5267A6C':
    server => 'hkp://keyserver.ubuntu.com:80'
  }
  
  ::apt::ppa { 'ppa:ondrej/php5-5.6':
    package_manage => true,
    require => ::Apt::Key['14AA40EC0831756756D7F66C4F4EA0AAE5267A6C']
  }
  
  class { 'php::cli': }
  
  file {[
      '/etc/php5/',
      '/etc/php5/cli',
      '/etc/php5/apache2',
      '/etc/php5/conf.d'
    ]:
    ensure => "directory",
  }
  
  php::ini {[
      '/etc/php.ini',
      '/etc/php5/cli/php.ini',
      '/etc/php5/apache2/php.ini',
    ]:
    max_execution_time => 600,
    max_input_time => 300,
    post_max_size => '50M',
    upload_max_filesize => '50M',
    memory_limit => '256M',
    date_timezone => 'America/New_York',
    max_input_vars => 5000,
    display_errors => 'On',
    html_errors => 'On',
    session_save_path => '/tmp',
    sendmail_path => '/usr/bin/env catchmail',
    notify => Service['httpd'],
    require => File['/etc/php5/apache2']
  }
  
  php::module {[
    'mysql',
    'intl',
    'mcrypt',
    'gd',
    'curl',
    'xdebug',
    'imagick',
    'memcached']:
    notify => Service['httpd'],
  }
  
  php::module::ini { 'xdebug' :
    settings => {
      'xdebug.remote_enable' => '1',
      'xdebug.remote_connect_back' => '1',
      'xdebug.idekey' => 'vagrant',
    },
    zend => '/usr/lib/php5/20131226',
    notify => Service['httpd'],
  }
  
  file { "/etc/php5/mods-available/xdebug.ini":
    ensure  => 'link',
    require => Package['php5-common'],
    target => '/etc/php5/conf.d/xdebug.ini',
    notify => Service['httpd'],
  }

  $opcache_settings = {
    'opcache.revalidate_freq' => '0',
    'opcache.memory_consumption' => '512',
    'opcache.max_accelerated_files' => '10000',
    'opcache.interned_strings_buffer' => '16',
    'opcache.fast_shutdown' => '1',
  }

  file { "/etc/php5/mods-available/opcache.ini":
    ensure  => 'file',
    require => Package['php5-common'],
    content => template('precip/opcache.ini.erb'),
    notify => Service['httpd'],
  }
  
  class { 'composer': 
    require => Class['php::cli']
  }
  
  # Add Composer's vendor directory to the vagrant user's $PATH
  file { '/home/vagrant/.pam_environment':
    mode    => 644,
    content => 'PATH DEFAULT=${PATH}:/home/vagrant/.composer/vendor/bin',
    require => Class['composer'],
  }
  
  # These bits install Drush & Friends via composer
  # 
  # file { "/home/vagrant/.composer/":
  #   ensure => 'directory',
  #   mode => '0755',
  #   owner => "vagrant",
  #   group => "vagrant",
  #   require => Class['composer'],
  # }
  # 
  # file { "/home/vagrant/.composer/composer.json":
  #   content => template("precip/composer.json"),
  #   ensure  => 'file',
  #   mode    => '0644',
  #   owner => "vagrant",
  #   group => "vagrant",
  #   require => [Class['composer'], File['/home/vagrant/.composer/']],
  # }
  #   
  # exec { "composer-install":
  #   command => "composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader",
  #   environment => [ "HOME=/home/vagrant", "COMPOSER_HOME=/home/vagrant/.composer" ],
  #   cwd => "/home/vagrant/.composer",
  #   path => "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin",
  #   user => "vagrant",
  #   require => [Class['composer'], File["/home/vagrant/.composer/composer.json"]],
  # }
}
