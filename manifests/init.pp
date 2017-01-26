class nginx (
  # Class parameters are populated from module hiera data
  Data $domains = {},
  String $web_root_parent = "/websites",
){

  $nginx_conf = "/etc/nginx"
  $nginx_vhosts_conf = "${nginx_conf}/vhosts.d"

  file { "${nginx_conf}":
    ensure  => directory,
  }

  file { "${nginx_vhosts_conf}":
    ensure  => directory,
    recurse => true,
    purge   => true,
  }

  # NGINX Virtual Host definition
  $domains.each | $domain, $config | {
    file { "${nginx_vhosts_conf}/${domain}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => epp('nginx/vhost_conf.epp', { domain => $domain, config => $config, web_root_parent => $web_root_parent} ),
      notify  => Service['nginx'],
    }
  }
  file { "${nginx_conf}/nginx.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => epp('nginx/nginx_conf.epp', { } ),
    notify  => Service['nginx'],
  }

  service { "nginx":
    ensure  => true,
    enable  => true,
  }

  package { 'nginx':
    ensure  => installed,
  }
  
}
