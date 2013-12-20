# Class: xtrabackup::remote
#
# import the exported rsync crons set for this node
# $::fqdn is used if it is not empty otherwise $::hostname is used
#
class xtrabackup::remote {
  $node_name = $::fqdn ? { /^$/ => $::hostname, default => $::fqdn }
  #import the crons for this server
  Cron <<| tag == "xtrabackup_${node_name}" |>>
}
