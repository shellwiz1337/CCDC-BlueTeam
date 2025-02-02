## apache service checklist

## 1. Basic stuff

[ ] audit services
    - list: chkconfig --list | grep ':on'
    - disable: chkconfig <servicename> off

[ ] audit authentication modules
    - list: httpd -M | egrep 'auth._'
    - check LDAP matches: httpd -M | egrep 'ldap'
    - check apache docs to see which ones to keep: 
        1. https://httpd.apache.org/docs/2.2/howto/auth.html
        2. https://httpd.apache.org/docs/2.2/mod/
        3. https://httpd.apache.org/docs/2.2/programs/configure.html

[ ] config logging
    - check if it is loaded: httpd -M | grep log_config 
    - load it: LoadModule log_config_module modules/mod_log_config.so

### 2. Disabling modules 
TO-DO: make this section a script
(httpd -M result should = 'Syntax OK')

[ ] webdav (allows clients to edit files on server)
    - check: httpd -M | grep ' dav_[[:print:]]+module'
    - comment out lines in httpd.conf:
        ##LoadModule dav_module modules/mod_dav.so
        ##LoadModule dav_fs_module modules/mod_dav_fs.so

[ ] mod_status
    - check: httpd -M | egrep 'status_module'
    - comment out lines in httpd.conf:
        ##LoadModule status_module modules/mod_status.so

[ ] mod_index
    - check:  httpd -M | grep autoindex_module
    - comment out line in httpd.conf:
        ## LoadModule autoindex_module modules/mod_autoindex.so

[ ] proxy server
    - check: httpd -M | grep proxy_
    - comment out lines in httpd.conf:
        ##LoadModule proxy_module modules/mod_proxy.so
        ##LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
        ##LoadModule proxy_ftp_module modules/mod_proxy_ftp.so
        ##LoadModule proxy_http_module modules/mod_proxy_http.so
        ##LoadModule proxy_connect_module modules/mod_proxy_connect.so
        ##LoadModule proxy_ajp_module modules/mod_proxy_ajp.so

[ ] userdir
    - check:  httpd -M | grep userdir_
    - comment out line in httpd.conf:
        ##LoadModule userdir_module modules/mod_userdir.so

[ ] mod_info
    - check: httpd -M | egrep 'info_module'
    - comment out line in httpd.conf:
        ##LoadModule info_module modules/mod_info.so

[ ] basic and digest auth
    - check: httpd -M | grep auth_basic_module;  httpd -M | grep auth_digest_module
    - comment out lines in httpd.conf:
        ##LoadModule mod_auth_basic modules/mod_auth_basic.so
        ##LoadModule mod_auth_digest modules/mod_auth_digest.so

## 3. Permissions/Priveledges

[ ] non-root user
    - check:
        1. ensure lines in httpd.conf are NOT commented out
            # grep -i '^User' $APACHE_PREFIX/conf/httpd.conf  
            User apache  
            # grep -i '^Group' $APACHE_PREFIX/conf/httpd.conf  
            Group apache  
        2. account uid < UID_MIN
            grep '^UID_MIN' /etc/login.defs  
            # id apach  
        3. group is one of the following: uid=48(apache) gid=48(apache) groups=48(apache)
        4. running user matches config:
            # ps axu | grep httpd | grep -v '^root'
    - fix:
        # groupadd -r apache
        # useradd apache -r -g apache -d /var/www -s /sbin/nologin
        # echo 'User apache' >> httpd.conf
        # echo 'Group apache' >> httpd.conf

[ ] invalid shell
    - check: # grep apache /etc/passwd = /sbin/nologin || /dev/null
    - fix: chsh -s /sbin/nologin apache
    
[ ] lock apache account
    - check: passwd -S apache = apache LK 2010-01-28 0 99999 7 -1 (Password locked.) or apache L 07/02/2012 -1 -1 -1 -1
    - fix: passwd -l apache

[ ] files should be owned by root
    - check:  find $APACHE_PREFIX \! -user root -ls
    - fix: chown -R root $APACHE_PREFIX
    
[ ] correct group:
    - check: find $APACHE_PREFIX -path $APACHE_PREFIX/htdocs -prune -o \! -group root - ls
    - fix: chgrp -R root $APACHE_PREFIX

[ ] restrict write access
    - check: find -L $APACHE_PREFIX \! -type l -perm /o=w -ls
    - fix:  chmod -R o-w $APACHE_PREFIX

[ ] secure core dump
    - check: ? 
    - fix:  chown root:apache /var/log/httpd; chmod o-rwx /var/log/httpd
    - possibly fix: ulimit -c 0 after ulimit -n in /etc/init.d/httpd ?

[ ] lock file
    - check:
        1. find LockFile in ServerRoot/logs
        2. verify only root has ownership and write
    - fix: ^

[ ] pid file
    - check

(left off pg 52 of apache CIS benchmark)

            
