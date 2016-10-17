class precip::php {
  apt::key { 'ppa:ondrej':
    id => '14AA40EC0831756756D7F66C4F4EA0AAE5267A6C',
  }

  apt::ppa { 'ppa:ondrej/php5-5.6':
    package_manage => true,
    require => Apt::Key['ppa:ondrej'],
  }
  
  class { 'php::cli': 
    require => [
      Apt::Ppa['ppa:ondrej/php5-5.6'],
    ]
  }
  
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
    max_input_vars => 10000,
    realpath_cache_size => 1024,
    display_errors => 'On',
    html_errors => 'On',
    session_save_path => '/tmp',
    sendmail_path => '/usr/bin/mailhog sendmail noreply@precip.vm',
    notify => Service['httpd'],
    require => File['/etc/php5/apache2']
  }
  
  php::module {[
    'curl',
    'gd',
    'imagick',
    'intl',
    'mcrypt',
    'memcached',
    'mysql',
    'sqlite',
    'xdebug']:
    notify => Service['httpd'],
  }
  
  php::module::ini { 'xdebug' :
    settings => {
      'xdebug.remote_autostart' => '1',
      'xdebug.remote_enable' => '1',
      'xdebug.remote_connect_back' => '1',
      'xdebug.idekey' => 'vagrant',
      'xdebug.max_nesting_level' => '10000',
    },
    zend => '/usr/lib/php5/20131226',
    notify => Service['httpd'],
  }
  
  $opcache_settings = {
    'opcache.enable_cli' => '1',
    'opcache.revalidate_freq' => '1',
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
  
  file { "/etc/php5/cli/conf.d/05-opcache.ini":
    ensure  => 'absent',
    require => Class['php::cli'],
  }
  
  class { 'composer': 
    require => Class['php::cli']
  }
  
  # Add Composer's vendor directory to the vagrant user's $PATH
  file { '/home/vagrant/.pam_environment':
    mode    => '0644',
    content => 'PATH DEFAULT=${PATH}:/home/vagrant/.composer/vendor/bin',
    require => Class['composer'],
  }
  
  # These bits install Drush & Friends via composer
  file { "/home/vagrant/.composer/":
    ensure => 'directory',
    mode => '0755',
    owner => "vagrant",
    group => "vagrant",
    require => Class['composer'],
  }
  
  file { "/home/vagrant/.composer/composer.json":
    content => template("precip/composer.json"),
    ensure  => 'file',
    mode    => '0644',
    owner => "vagrant",
    group => "vagrant",
    require => [Class['composer'], File['/home/vagrant/.composer/']],
  }
    
  exec { "install-composer-libraries":
    command => "composer install --no-interaction --prefer-dist --no-dev --optimize-autoloader",
    environment => [ "HOME=/home/vagrant", "COMPOSER_HOME=/home/vagrant/.composer" ],
    cwd => "/home/vagrant/.composer",
    path => "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin",
    user => "vagrant",
    require => [Class['composer'], File["/home/vagrant/.composer/composer.json"]],
  }
}
