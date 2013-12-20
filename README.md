abstractitptyltd-xtrabackup
====

####Table of Contents

1. [Overview - What is the xtrabackup module?](#overview)
2. [Module Description - What does the module do?](#module-description)
3. [Setup - The basics of getting started with xtrabackup](#setup)
4. [Usage - The parameters available for configuration](#usage)
5. [Implementation - An under-the-hood peek at what the module is doing](#implementation)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)
8. [Release Notes - Notes on the most recent updates to the module](#release-notes)

Overview
--------

Puppet module for setting up percona xtrabackup to backup a MariaDB, Percona or MySQL server

Module Description
------------------

Manages incremental and/or differential and full backups of your data directory using Perconas awesome xtrabackup.


Setup
-----

**what xtrabackup affects:**

* the xtrabackup sericve
* configuration files for xtrabackup

### Beginning with xtrabackup

This will manage a basic setup for xtrabackup.

    # on your database node
    include xtrabackup
    # set these vars with hiera
    $xtrabackup::type # incremental, differential or both
    $xtrabackup::backup_server # $::fqdn of backup server (defaults to backup.$::domain)
    $xtrabackup::inc_hours # array of hours for incremental backup
    $xtrabackup::diff_hours # array of hours for differential backup
    $xtrabackup::full_hours # array of hours for full backup
    $xtrabackup::full_keep # age of full backup files to keep in tidy format ie: 1w, 1d etc
    $xtrabackup::inc_keep # age of incremental backup files to keep in tidy format ie: 1w, 1d etc
    $xtrabackup::diff_keep # age of differential baclup files to keep in tidy format ie: 1w, 1d etc

    # or as class vars
    # incremental backups
    class { 'xtrabackup':
      type          => 'incremental',
      full_hours    => ['9','18'],
      inc_hours     => ['0','12'],
      full_keep     => '1w',
      inc_keep      => '1d',
      backup_server => 'backup.domain.com',
    }
    # diferential backups
    class { 'xtrabackup':
      type          => 'differential',
      full_hours    => ['9','18'],
      inc_hours     => ['0','12'],
      full_keep     => '1w',
      diff_keep     => '1d',
      backup_server => 'backup.domain.com',
    }
    # both
    class { 'xtrabackup':
      type          => 'both',
      full_hours    => ['18'],
      inc_hours     => ['0','12'],
      diff_hours    => ['6','9'],
      full_keep     => '1w',
      inc_keep      => '1d',
      diff_keep     => '1d',
      backup_server => 'backup.domain.com',
    }

    # on your backup server
    # this will import all rsyncs where the fqdn of this noce was used as the backup_server
    include xtrabackup::remote

Usage
-----


Implementation
--------------

Uses files based on templates to manage the xtrabackup configuration files

Limitations
------------

Backup crons need stored configs on your puppet master. I recommend using PuppetDB for this.

Development
-----------

All development, testing and releasing is done by Abstract IT at this stage.
If you wish to join in let me know.

Release Notes
-------------

**0.1.0**

Initial release
