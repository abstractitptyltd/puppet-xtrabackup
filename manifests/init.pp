# Class: xtrabackup
#
# setup xtrabackup crons
#
class xtrabackup (
  $rsync_opts = '-aqzP --bwlimit=256 -e "ssh"',
  $backup_server = "backup.${::domain}",
  $type = 'incremental',
  $master_name = $::domain,
  $encrypt = false,
  $gpg_pub_key = undef,
  $recipient = "root@${::domain}",
  $checkpoint_dir = '/srv/xtrabackup_checkpoints',
  $base_dir = '/srv/xtrabackup',
  $remote_base_dir = '/srv/xtrabackup_remote',
  $archive_dir = '/srv/xtrabackup_archive',
  $inc_hours = hiera_array('xtrabackup::params::inc_hours', []),
  $diff_hours = hiera_array('xtrabackup::params::diff_hours', []),
  $full_hours = hiera_array('xtrbaackup::params::full_hours', []),
  $full_keep = 0,
  $inc_keep = 0,
  $diff_keep = 0,
  $remote_hours = hiera_array('xtrabackup::params::remote_hours', []),
) {
  validate_re($type, '^incremental|differential|both$')
  if $encrypt {
    warn('Please ensure gpg key is imported and trusted otherwise backups will fail')
  }

  $packages = ['percona-xtrabackup','gnupg2']
  if (! defined(Package['percona-xtrabackup']) ) {
    package { 'percona-xtrabackup':
      ensure => installed,
    }
  }
  if (! defined(Package['gnupg2']) ) {
    package { 'gnupg2':
      ensure => installed,
    }
  }

  file { [$archive_dir,$checkpoint_dir]:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  $year = strftime('%Y')
  $month = strftime('%m')
  $day = strftime('%d')
  $today_dir = "${archive_dir}/${year}/${month}/${day}"

  $date_cmd = '`date +"\%F_\%R"`'
  $year_cmd = '`date +"\%Y"`'
  $month_cmd = '`date +"\%m"`'
  $day_cmd = '`date +"\%d"`'
  $backup_cmd = 'innobackupex --stream=xbstream '
  $archive_cmd = $encrypt ? { true => " gpg --batch --yes --no-tty -e -r ${recipient} -o ", false => ' gzip - > ' }
  $extension = $encrypt ? { true => 'xbstream.gz.gpg', false => 'xbstream.gz' }

  $full_backup = "mkdir -p ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd} && ${backup_cmd} --extra-lsndir=${checkpoint_dir} /tmp | ${archive_cmd} ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd}/${master_name}_${date_cmd}_full.${extension}"
  $inc_backup = "mkdir -p ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd} && ${backup_cmd} --extra-lsndir=${checkpoint_dir} --incremental --incremental-basedir=${checkpoint_dir} /tmp | ${archive_cmd} ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd}/${master_name}_${date_cmd}_incremental.${extension}"
  $diff_backup = "mkdir -p ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd} && ${backup_cmd} --incremental --incremental-basedir=${checkpoint_dir} /tmp | ${archive_cmd} ${archive_dir}/${year_cmd}/${month_cmd}/${day_cmd}/${master_name}_${date_cmd}_differntial.${extension}"

  if ( empty($full_hours) ) {
    fail('not setting full backup cron, full_hours in empty')
  } else {
    # full backup cron
    cron {"xtrabackup ${master_name} full backup":
      command => $full_backup,
      user    => root,
      hour    => $full_hours,
      minute  => 0,
    }
    if $type =~ /^(incremental|both)$/ {
      # incremental backup cron
      if ( empty($inc_hours) ) {
        err('not setting incremental cron, inc_hours in empty')
      } else {
        cron {"xtrabackup ${master_name} incremental backup":
          command  => $inc_backup,
          user     => root,
          hour     => $inc_hours,
          minute   => 0,
        }
      }
    } else {
      cron {"xtrabackup ${master_name} incremental backup":
        ensure   => absent,
        command  => $inc_backup,
        user     => root,
        hour     => $inc_hours,
        minute   => 0,
      }
    }
    if $type =~ /^(differential|both)$/ {
      # differential backup cron
      if ( empty($diff_hours) ) {
        err('not setting differential cron, diff_hours in empty')
      } else {
        cron {"xtrabackup ${master_name} differential backup":
          command  => $diff_backup,
          user     => root,
          hour     => $diff_hours,
          minute   => 0,
        }
      }
    } else {
      cron {"xtrabackup ${master_name} differential backup":
        ensure   => absent,
        command  => $diff_backup,
        user     => root,
        hour     => $diff_hours,
        minute   => 0,
      }
    }


    if ( empty($remote_hours) ) {
      err('disabling remote backup cron, remote_hours is empty')
      @@cron { "xtrabackup_${::fqdn}_${master_name}":
        ensure  => absent,
        command => "rsync ${xtrabackup::params::rsync_opts} ${::fqdn}:${archive_dir}/ ${remote_base_dir}/${master_name}/",
        user    => root,
        hour    => $remote_hours,
        minute  => 10,
        tag     => "xtrabackup_${xtrabackup::params::backup_server}",
      }
    } else {
      # exported cron to rsync to backup server
      @@cron { "xtrabackup_${::fqdn}_${master_name}":
        command => "rsync ${xtrabackup::params::rsync_opts} ${::fqdn}:${archive_dir}/ ${remote_base_dir}/${master_name}/",
        user    => root,
        hour    => $remote_hours,
        minute  => 10,
        tag     => "xtrabackup_${xtrabackup::params::backup_server}",
      }
    }

    if $full_keep != 0 {
      ## tidy up old backups
      tidy { 'xtrabackup_cleanup_full':
        path    => $archive_dir,
        recurse => true,
        rmdirs  => true,
        matches => "${master_name}_*_full.${extension}",
        type    => mtime,
        age     => $full_keep,
        backup  => false,
      }
    }
    if $inc_keep != 0 {
      ## tidy up old backups
      tidy { 'xtrabackup_cleanup_inc':
        path    => $archive_dir,
        recurse => true,
        rmdirs  => true,
        matches => "${master_name}_*_incremental.${extension}",
        type    => mtime,
        age     => $inc_keep,
        backup  => false,
      }
    }
    if $diff_keep != 0 {
      ## tidy up old backups
      tidy { 'xtrabackup_cleanup_diff':
        path    => $archive_dir,
        recurse => true,
        rmdirs  => true,
        matches => "${master_name}_*_differential.${extension}",
        type    => mtime,
        age     => $diff_keep,
        backup  => false,
      }
    }

  }

}

