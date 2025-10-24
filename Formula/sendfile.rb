require 'formula'

class Sendfile < Formula
  homepage 'https://fex.belwue.de/saft/sendfile.html'
  url 'http://fex.belwue.de/download/sendfile-2.1b.tar.gz'
  sha256 'd0b4305c38e635d67bb2e316ccaf1d3afde63e67b748a104582d0ce9cf7f2a8c'

  # source code:
  #  - remove nested "MAXS() inside snprintf()" macros.
  #  - disable wtmp/utmp on Mac OS X.
  #  - only call seteuid() & setegid() when it would change user/group.
  patch :DATA

  def install
    inreplace ["makeconfig", "etc/sfdconf", "doc/receive.1", "doc/sendfile.1", "doc/sendmsg.1", "doc/sendfiled.8" ] do |s|
      s.gsub! "/usr/local", "#{HOMEBREW_PREFIX}"
      s.gsub! "/var/spool/sendfile", (var + 'spool/sendfile')
    end

    system "make config"
    system "make all"

    sbin.install 'src/sendfiled'
    sbin.install 'etc/sfdconf'
    bin.install 'src/fetchfile', 'src/receive', 'src/sendfile', 'src/sendmsg'
    bin.install 'src/utf7encode', 'src/wlock'
    bin.install 'etc/check_sendfile', 'etc/sfconf'
    etc.install 'etc/sendfile.cf', 'etc/sendfile.deny'
    man1.install 'doc/fetchfile.1', 'doc/receive.1', 'doc/sendfile.1', 'doc/sendmsg.1'
    man1.install 'doc/utf7encode.1', 'doc/wlock.1'
    man8.install 'doc/sendfiled.8'

    (var + 'spool/sendfile/LOG').mkpath
    (var + 'spool/sendfile/OUTGOING').mkpath
    (var + 'spool/sendfile/LOG').chmod 00700
    (var + 'spool/sendfile/OUTGOING').chmod 01777
  end

  def caveats
    <<-EOCAVEATS
The sendfiled(8) daemon is installed but not started by this Homebrew formula.
If you want to run the daemon, you have to take care of it yourself!
    EOCAVEATS
  end

end

__END__

 src/address.c   |   66 ++++++++--------
 src/fetchfile.c |  126 ++++++++++++++--------------
 src/io.c        |   28 +++---
 src/net.c       |   32 ++++----
 src/receive.c   |  216 ++++++++++++++++++++++++------------------------
 src/sendfile.c  |  242 +++++++++++++++++++++++++++---------------------------
 src/sendfiled.c |  180 +++++++++++++++++++++--------------------
 src/sendmsg.c   |   20 +++---
 src/spool.c     |   38 +++++-----
 9 files changed, 475 insertions(+), 473 deletions(-)

diff --git a/src/address.c b/src/address.c
index 4c75028..dcf6cd1 100644
--- a/src/address.c
+++ b/src/address.c
@@ -134,15 +134,15 @@ void destination(int argc, char **argv,
   snprintf(user,FLEN-1,"%s %s",pwe->pw_name,gecos);
   
   /* check user configuration directory */
-  snprintf(MAXS(userconfig),"%s/.sendfile",pwe->pw_dir);
-  snprintf(MAXS(tmp),SPOOL"/%s/config",pwe->pw_name);
+  snprintf(userconfig,sizeof(userconfig)-1,"%s/.sendfile",pwe->pw_dir);
+  snprintf(tmp,sizeof(tmp)-1,SPOOL"/%s/config",pwe->pw_name);
   if (stat(userconfig,&finfo)<0 && stat(tmp,&finfo)==0)
     symlink(tmp,userconfig);
   
   /* trick: argc == 0, when message reply mode */
   if (argc==0) {
     if (gethostname(localhost,FLEN-1)<0) strcpy(localhost,"localhost");
-    snprintf(MAXS(tmp),"%s/msg@%s",userconfig,localhost);
+    snprintf(tmp,sizeof(tmp)-1,"%s/msg@%s",userconfig,localhost);
     if ((inf=rfopen(tmp,"r")) && fgetl(line,inf)) {
       if ((cp=strchr(line,'\n'))) *cp=0;
       if ((cp=strchr(line,'@'))) {
@@ -187,12 +187,12 @@ void destination(int argc, char **argv,
     strcpy(recipient,larg);
 
     /* check the sendfile alias file */
-    snprintf(MAXS(aliasfile),"%s/aliases",userconfig);
+    snprintf(aliasfile,sizeof(aliasfile)-1,"%s/aliases",userconfig);
     if (check_alias(aliasfile,recipient,host,aopt)<0) {
      
 #ifdef RESPECT_MAIL_ALIASES
       /* check the elm alias file */
-      snprintf(MAXS(aliasfile),"%s/.elm/aliases.text",pwe->pw_dir);
+      snprintf(aliasfile,sizeof(aliasfile)-1,"%s/.elm/aliases.text",pwe->pw_dir);
       if (check_alias(aliasfile,recipient,host,aopt)<0) {
        
 #endif
@@ -342,7 +342,7 @@ int check_forward(int sockfd, char *recipient, char *host, char *redirect) {
 
   /* illegal answer */
   if (!str_beq(reply,"200 ")) {
-    snprintf(MAXS(tmp),"server error: %s",reply+4);
+    snprintf(tmp,sizeof(tmp)-1,"server error: %s",reply+4);
     errno=0;
     if (client) message(prg,'F',tmp);
     strcpy(redirect,reply+4);
@@ -405,7 +405,7 @@ int saft_connect(const char *type,
     /* if the finger-port is specified get real port from there */
     if (port==79 || !port) {
       if ((cp=strchr(host,':'))) *cp=0;
-      snprintf(MAXS(tmp),"opening connection to finger://%s/%s",host,recipient);
+      snprintf(tmp,sizeof(tmp)-1,"opening connection to finger://%s/%s",host,recipient);
       if (quiet<2) message(prg,'I',tmp);
       port=finger_saft_port(recipient,host);
       if (port<1) {
@@ -417,7 +417,7 @@ int saft_connect(const char *type,
     }
       
     /* initiate the SAFT-connection to the server */
-    snprintf(MAXS(tmp),"opening connection to saft://%s/%s",host,recipient);
+    snprintf(tmp,sizeof(tmp)-1,"opening connection to saft://%s/%s",host,recipient);
     if (quiet<2) message(prg,'I',tmp);
     sockfd=open_connection(host,port);
 
@@ -426,13 +426,13 @@ int saft_connect(const char *type,
       /* host has no ip-address, but we can try more ... */
       if (sockfd==-3 && str_eq(type,"file")) {
 	if (client) {
-	  snprintf(MAXS(tmp),"%s has no internet-address",host);
+	  snprintf(tmp,sizeof(tmp)-1,"%s has no internet-address",host);
 	  if (quiet<2) message(prg,'W',tmp);
 	}
     
 	/* try generic saft-address for this host/domain */
 	if (port==SAFT) {
-	  snprintf(MAXS(ahost),"saft.%s",host);
+	  snprintf(ahost,sizeof(ahost)-1,"saft.%s",host);
 	  if (client) {
 	    if(gethostbyname(ahost)){
 	      if (!quiet) {
@@ -446,7 +446,7 @@ int saft_connect(const char *type,
 	  if (tolower(*answer)!='n' || !client) {
 	    strcpy(host,ahost);
 	    if (client) {
-	      snprintf(MAXS(tmp),"opening connection to %s@%s",recipient,host);
+	      snprintf(tmp,sizeof(tmp)-1,"opening connection to %s@%s",recipient,host);
 	      if (quiet<2) message(prg,'I',tmp);
 	    }
 	    sockfd=open_connection(host,port);
@@ -458,13 +458,13 @@ int saft_connect(const char *type,
       /* try user SAFT port on connection failure */
       if (sockfd==-2 && str_eq(type,"file")) {
 	if (verbose) {
-	  snprintf(MAXS(tmp),"cannot connect to SAFT port %d on %s",
+	  snprintf(tmp,sizeof(tmp)-1,"cannot connect to SAFT port %d on %s",
 		   port,host);
 	  message(prg,'E',tmp);
 	}
 	port=finger_saft_port(recipient,host);
 	if (port>0 && port!=SAFT) {
-	  snprintf(MAXS(tmp),"%s has no system SAFT server, "
+	  snprintf(tmp,sizeof(tmp)-1,"%s has no system SAFT server, "
 		   "trying user SAFT server on port %d",host,port);
 	  if (quiet<2) message(prg,'W',tmp);
 	  sockfd=open_connection(host,port);
@@ -474,9 +474,9 @@ int saft_connect(const char *type,
       
     }
     
-    if (sockfd==-1) snprintf(MAXS(tmp),"cannot create a network socket");
-    if (sockfd==-2) snprintf(MAXS(tmp),"cannot open connection to %s",host);
-    if (sockfd==-3) snprintf(MAXS(tmp),"%s is unknown",host);
+    if (sockfd==-1) snprintf(tmp,sizeof(tmp)-1,"cannot create a network socket");
+    if (sockfd==-2) snprintf(tmp,sizeof(tmp)-1,"cannot open connection to %s",host);
+    if (sockfd==-3) snprintf(tmp,sizeof(tmp)-1,"%s is unknown",host);
     if (sockfd<0) {
       if (client) {
 	errno=0;
@@ -488,7 +488,7 @@ int saft_connect(const char *type,
     /* no remote server or protocol error? */
     sock_getline(sockfd,line);
     if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) {
-      snprintf(MAXS(tmp),"No SAFT server on port %d at %s",port,host);
+      snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %d at %s",port,host);
       if ((cp=strrchr(tmp,':'))) *cp=0;
       if (client) {
 	errno=0;
@@ -500,9 +500,9 @@ int saft_connect(const char *type,
     }
 
     /* send constant header lines */
-    snprintf(MAXS(tmp),"FROM %s",user);
+    snprintf(tmp,sizeof(tmp)-1,"FROM %s",user);
     sendheader(sockfd,tmp);
-    snprintf(MAXS(tmp),"TO %s",recipient);
+    snprintf(tmp,sizeof(tmp)-1,"TO %s",recipient);
     sock_putline(sockfd,tmp);
 
     /* is there a forward set? */
@@ -659,7 +659,7 @@ int saft_connect(const char *type,
       } else {
         if ((cp=strchr(host,':'))) *cp=0;
       }
-      snprintf(MAXS(tmp),"opening connection to finger://%s/%s",host,recipient);
+      snprintf(tmp,sizeof(tmp)-1,"opening connection to finger://%s/%s",host,recipient);
       if (quiet<2) message(prg,'I',tmp);
       service=finger_saft_port(recipient,host);
       if (service==NULL) {
@@ -671,7 +671,7 @@ int saft_connect(const char *type,
     }
       
     /* initiate the SAFT-connection to the server */
-    snprintf(MAXS(tmp),"opening connection to saft://%s/%s",host,recipient);
+    snprintf(tmp,sizeof(tmp)-1,"opening connection to saft://%s/%s",host,recipient);
     if (quiet<2) message(prg,'I',tmp);
     sockfd=open_connection(host,service);
 
@@ -680,13 +680,13 @@ int saft_connect(const char *type,
       /* host has no ip-address, but we can try more ... */
       if (sockfd==-3 && str_eq(type,"file")) {
 	if (client) {
-	  snprintf(MAXS(tmp),"%s has no internet-address",host);
+	  snprintf(tmp,sizeof(tmp)-1,"%s has no internet-address",host);
 	  if (quiet<2) message(prg,'W',tmp);
 	}
     
 	/* try generic saft-address for this host/domain */
 	if (strcasecmp(service, SERVICE) == 0 || strcmp(service, PORT_STRING) == 0) {
-	  snprintf(MAXS(ahost),"saft.%s",host);
+	  snprintf(ahost,sizeof(ahost)-1,"saft.%s",host);
 	  if (client) {
 	    sockfd=open_connection(host,service);
 	    if(sockfd >= 0){
@@ -701,7 +701,7 @@ int saft_connect(const char *type,
 	  if (tolower(*answer)!='n' || !client) {
 	    strcpy(host,ahost);
 	    if (client) {
-	      snprintf(MAXS(tmp),"opening connection to %s@%s",recipient,host);
+	      snprintf(tmp,sizeof(tmp)-1,"opening connection to %s@%s",recipient,host);
 	      if (quiet<2) message(prg,'I',tmp);
 	    }
 	  } else {
@@ -715,14 +715,14 @@ int saft_connect(const char *type,
       /* try user SAFT port on connection failure */
       if (sockfd==-2 && str_eq(type,"file")) {
 	if (verbose) {
-	  snprintf(MAXS(tmp),"cannot connect to SAFT port %s on %s",
+	  snprintf(tmp,sizeof(tmp)-1,"cannot connect to SAFT port %s on %s",
 		   service,host);
 	  message(prg,'E',tmp);
 	}
 	service=finger_saft_port(recipient,host);
         if (service != NULL) needsFree = 1;
 	if (service != NULL && strcasecmp(service, SERVICE) != 0 && strcmp(service, PORT_STRING) != 0) {
-	  snprintf(MAXS(tmp),"%s has no system SAFT server, "
+	  snprintf(tmp,sizeof(tmp)-1,"%s has no system SAFT server, "
 		   "trying user SAFT server on port %s",host,service);
 	  if (quiet<2) message(prg,'W',tmp);
 	  sockfd=open_connection(host,service);
@@ -733,10 +733,10 @@ int saft_connect(const char *type,
       
     }
     
-    if (sockfd==-1) snprintf(MAXS(tmp),"cannot create a network socket");
-    if (sockfd==-2) snprintf(MAXS(tmp),"cannot open connection to %s",host);
-    if (sockfd==-3) snprintf(MAXS(tmp),"%s is unknown",host);
-    if (sockfd==-4) snprintf(MAXS(tmp),"out of memory");
+    if (sockfd==-1) snprintf(tmp,sizeof(tmp)-1,"cannot create a network socket");
+    if (sockfd==-2) snprintf(tmp,sizeof(tmp)-1,"cannot open connection to %s",host);
+    if (sockfd==-3) snprintf(tmp,sizeof(tmp)-1,"%s is unknown",host);
+    if (sockfd==-4) snprintf(tmp,sizeof(tmp)-1,"out of memory");
     if (sockfd<0) {
       if (client) {
 	errno=0;
@@ -750,7 +750,7 @@ int saft_connect(const char *type,
     /* no remote server or protocol error? */
     sock_getline(sockfd,line);
     if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) {
-      snprintf(MAXS(tmp),"No SAFT server on port %s at %s",service,host);
+      snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %s at %s",service,host);
       if ((cp=strrchr(tmp,':'))) *cp=0;
       if (client) {
 	errno=0;
@@ -763,9 +763,9 @@ int saft_connect(const char *type,
     }
 
     /* send constant header lines */
-    snprintf(MAXS(tmp),"FROM %s",user);
+    snprintf(tmp,sizeof(tmp)-1,"FROM %s",user);
     sendheader(sockfd,tmp);
-    snprintf(MAXS(tmp),"TO %s",recipient);
+    snprintf(tmp,sizeof(tmp)-1,"TO %s",recipient);
     sock_putline(sockfd,tmp);
 
     /* is there a forward set? */
diff --git a/src/fetchfile.c b/src/fetchfile.c
index bd9d3c7..cb12354 100644
--- a/src/fetchfile.c
+++ b/src/fetchfile.c
@@ -215,14 +215,14 @@ int main(int argc, char *argv[]) {
   tmpdir=mktmpdir(verbose);
 
   /* set various file names and check user spool and configuration directory */
-  snprintf(MAXS(pgptmp),"%s/fetchfile.pgp",tmpdir);
-  snprintf(MAXS(userspool),SPOOL"/%s",pwe->pw_name);
+  snprintf(pgptmp,sizeof(pgptmp)-1,"%s/fetchfile.pgp",tmpdir);
+  snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pwe->pw_name);
   if (stat(userspool,&finfo)<0) sendfiled_test(pwe->pw_name);
-  snprintf(MAXS(userconfig),"%s/.sendfile",pwe->pw_dir);
-  snprintf(MAXS(tmp),"%s/config",userspool);
+  snprintf(userconfig,sizeof(userconfig)-1,"%s/.sendfile",pwe->pw_dir);
+  snprintf(tmp,sizeof(tmp)-1,"%s/config",userspool);
   if (stat(userconfig,&finfo)<0 && stat(userspool,&finfo)==0)
     symlink(tmp,userconfig);
-  snprintf(MAXS(tmp),"%s/.sfspool",pwe->pw_dir);
+  snprintf(tmp,sizeof(tmp)-1,"%s/.sfspool",pwe->pw_dir);
   if (stat(tmp,&finfo)==0 && finfo.st_mode&S_IFDIR) strcpy(userspool,tmp);
 
   /* scan the command line on options */
@@ -303,7 +303,7 @@ int main(int argc, char *argv[]) {
   /* check tmp files */
   unlink(pgptmp);
   if (stat(pgptmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",pgptmp);
     message(prg,'F',tmp);
   }
@@ -332,19 +332,19 @@ int main(int argc, char *argv[]) {
   }
 
   /* check pgp key files */
-  snprintf(MAXS(tmp),"%s/private.pgp",userconfig);
+  snprintf(tmp,sizeof(tmp)-1,"%s/private.pgp",userconfig);
   if (stat(tmp,&finfo)<0) {
-    snprintf(MAXS(line),"no access to %s (try 'fetchfile -I' first)",tmp);
+    snprintf(line,sizeof(line)-1,"no access to %s (try 'fetchfile -I' first)",tmp);
     message(prg,'F',line);
   }
-  snprintf(MAXS(tmp),"%s/public.pgp",userconfig);
+  snprintf(tmp,sizeof(tmp)-1,"%s/public.pgp",userconfig);
   if (stat(tmp,&finfo)<0) {
-    snprintf(MAXS(line),"no access to %s (try 'fetchfile -I' first)",tmp);
+    snprintf(line,sizeof(line)-1,"no access to %s (try 'fetchfile -I' first)",tmp);
     message(prg,'F',line);
   }
   
   /* parse the user config-file */
-  snprintf(MAXS(tmp),"%s/config",userconfig);
+  snprintf(tmp,sizeof(tmp)-1,"%s/config",userconfig);
   if ((inf=rfopen(tmp,"r"))) {
     while (fgetl(line,inf)) {
       
@@ -386,24 +386,24 @@ int main(int argc, char *argv[]) {
 
   if (!*id) strcpy(id,pwe->pw_name);
   if (!*server) strcpy(server,"localhost");
-  snprintf(MAXS(listfile),"%s/%s@%s:fetch.lis",userspool,id,server);
+  snprintf(listfile,sizeof(listfile)-1,"%s/%s@%s:fetch.lis",userspool,id,server);
   
   /* initiate the connection to the server */
   if (!*server) {
     errno=0;
     message(prg,'F',"no SAFT server is defined");
   }
-  snprintf(MAXS(tmp),"connecting to SAFT server %s",server);
+  snprintf(tmp,sizeof(tmp)-1,"connecting to SAFT server %s",server);
   if (quiet<2) message(prg,'I',tmp);
 #ifndef ENABLE_MULTIPROTOCOL
   sockfd=open_connection(server,SAFT);
 #else
   sockfd=open_connection(server,SERVICE);
 #endif
-  if (sockfd==-1) snprintf(MAXS(tmp),"cannot create a network socket");
-  if (sockfd==-2) snprintf(MAXS(tmp),"cannot open connection to %s",server);
-  if (sockfd==-3) snprintf(MAXS(tmp),"%s is unknown",server);
-  if (sockfd==-4) snprintf(MAXS(tmp),"out of memory");
+  if (sockfd==-1) snprintf(tmp,sizeof(tmp)-1,"cannot create a network socket");
+  if (sockfd==-2) snprintf(tmp,sizeof(tmp)-1,"cannot open connection to %s",server);
+  if (sockfd==-3) snprintf(tmp,sizeof(tmp)-1,"%s is unknown",server);
+  if (sockfd==-4) snprintf(tmp,sizeof(tmp)-1,"out of memory");
   if (sockfd<0) {
     errno=0;
     message(prg,'F',tmp);
@@ -413,22 +413,22 @@ int main(int argc, char *argv[]) {
   sock_getline(sockfd,line);
   if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) {
     errno=0;
-    snprintf(MAXS(tmp),"No SAFT server on port %d at %s",SAFT,server);
+    snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %d at %s",SAFT,server);
     message(prg,'F',tmp);
   }
   
   /* send ID */
-  snprintf(MAXS(tmp),"ID %s",id);
+  snprintf(tmp,sizeof(tmp)-1,"ID %s",id);
   sock_putline(sockfd,tmp);
   sock_getline(sockfd,line);
   if (str_beq(line,"520")) {
     errno=0;
-    snprintf(MAXS(tmp),"user %s is unknown on SAFT-server %s",id,server);
+    snprintf(tmp,sizeof(tmp)-1,"user %s is unknown on SAFT-server %s",id,server);
     message(prg,'F',tmp);
   }
   if (!str_beq(line,"331")) {
     errno=0;
-    snprintf(MAXS(tmp),"server error: %s",line+4);
+    snprintf(tmp,sizeof(tmp)-1,"server error: %s",line+4);
     message(prg,'F',tmp);
   }
   str_trim(line);
@@ -440,7 +440,7 @@ int main(int argc, char *argv[]) {
   outf=rfopen(pgptmp,"w");
   if (!outf) {
     errno=0;
-    snprintf(MAXS(tmp),"cannot open/write to %s",pgptmp);
+    snprintf(tmp,sizeof(tmp)-1,"cannot open/write to %s",pgptmp);
     message(prg,'F',tmp);
   }
   fprintf(outf,"%s",cp+1);
@@ -448,13 +448,13 @@ int main(int argc, char *argv[]) {
 
   /* goto user spool directory */
   if (chdir(userspool)<0) {
-    snprintf(MAXS(tmp),"cannot change to %s",userspool);
+    snprintf(tmp,sizeof(tmp)-1,"cannot change to %s",userspool);
     message(prg,'F',tmp);
   }
   
   /* call pgp */
   /* DONT REMOVE 2>/dev/null IN THE FOLLOWING LINE! */
-  snprintf(MAXS(cmd),"cd %s; PGPPATH='.' %s -sbaf "
+  snprintf(cmd,sizeof(cmd)-1,"cd %s; PGPPATH='.' %s -sbaf "
 	   "+secring=private.pgp +pubring=public.pgp <%s 2>/dev/null",
 	   userconfig,pgp_bin,pgptmp);
   if (verbose) printf("call: %s\n",cmd);
@@ -478,7 +478,7 @@ int main(int argc, char *argv[]) {
   }
   
   iso2utf(tmp,response);
-  snprintf(MAXS(response),"AUTH %s",tmp);
+  snprintf(response,sizeof(response)-1,"AUTH %s",tmp);
   sendheader(sockfd,response);
 
   /* config file transfer? */
@@ -492,7 +492,7 @@ int main(int argc, char *argv[]) {
     if (*tmp == '/')
       strcpy(conffile,tmp);
     else
-      snprintf(MAXS(conffile),"%s/%s",swd,tmp);
+      snprintf(conffile,sizeof(conffile)-1,"%s/%s",swd,tmp);
 
     /* write config file */
     if (wconf) {
@@ -501,23 +501,23 @@ int main(int argc, char *argv[]) {
 	cp++;
       else
 	cp=conffile;
-      snprintf(MAXS(tmp),"CONF WRITE %s",cp);
+      snprintf(tmp,sizeof(tmp)-1,"CONF WRITE %s",cp);
       sock_putline(sockfd,tmp);
       sock_getline(sockfd,line);
       if (!str_beq(line,"302 ") && !str_beq(line,"200 ")) {
 	errno=0;
-	snprintf(MAXS(tmp),"server error: %s",line+4);
+	snprintf(tmp,sizeof(tmp)-1,"server error: %s",line+4);
 	message(prg,'F',tmp);
       }
     
       inf=rfopen(conffile,"r");
       if (!inf) {
-	snprintf(MAXS(tmp),"cannot open %s",conffile);
+	snprintf(tmp,sizeof(tmp)-1,"cannot open %s",conffile);
 	message(prg,'F',tmp);
       }
 
       if (quiet<2) {
-	snprintf(MAXS(tmp),"transfering %s",conffile);
+	snprintf(tmp,sizeof(tmp)-1,"transfering %s",conffile);
 	message(prg,'I',tmp);
       }
       
@@ -532,7 +532,7 @@ int main(int argc, char *argv[]) {
       sock_getline(sockfd,line);
       if (!str_beq(line,"201 ")) {
 	errno=0;
-	snprintf(MAXS(tmp),"server error: %s",line+4);
+	snprintf(tmp,sizeof(tmp)-1,"server error: %s",line+4);
 	message(prg,'F',tmp);
       }
     
@@ -542,12 +542,12 @@ int main(int argc, char *argv[]) {
 	cp++;
       else
 	cp=conffile;
-      snprintf(MAXS(tmp),"CONF READ %s",cp);
+      snprintf(tmp,sizeof(tmp)-1,"CONF READ %s",cp);
       sock_putline(sockfd,tmp);
       while (sock_getline(sockfd,line)) {
 	if (!str_beq(line,"250")) {
 	  errno=0;
-	  snprintf(MAXS(tmp),"server error: %s",line+4);
+	  snprintf(tmp,sizeof(tmp)-1,"server error: %s",line+4);
 	  message(prg,'F',tmp);
 	}
 	if (str_beq("250 ",line)) break;
@@ -592,11 +592,11 @@ int main(int argc, char *argv[]) {
       number=atoi(argv[i]);
       if (del) {
 	if (delete_file(sockfd,number)<0) {
-	  snprintf(MAXS(tmp),"cannot delete file #%d from server",number);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot delete file #%d from server",number);
 	  errno=0;
 	  message(prg,'E',prg);
 	} else {
-	  snprintf(MAXS(tmp),"file #%d deleted from server",number);
+	  snprintf(tmp,sizeof(tmp)-1,"file #%d deleted from server",number);
 	  if (quiet<2) message(prg,'I',tmp);
 	  n++;
 	}
@@ -616,7 +616,7 @@ int main(int argc, char *argv[]) {
     get_list(sockfd,server,id,listf);
     fclose(listf);
   } else {
-    snprintf(MAXS(tmp),"cannot open %s for writing",listfile);
+    snprintf(tmp,sizeof(tmp)-1,"cannot open %s for writing",listfile);
     message(prg,'F',tmp);
   }
 
@@ -624,7 +624,7 @@ int main(int argc, char *argv[]) {
   if (all) {
     listf=rfopen(listfile,"r");
     if (!listf) {
-      snprintf(MAXS(tmp),"cannot open %s for reading",listfile);
+      snprintf(tmp,sizeof(tmp)-1,"cannot open %s for reading",listfile);
       message(prg,'F',tmp);
     }
     while (fgetl(line,listf)) {
@@ -642,11 +642,11 @@ int main(int argc, char *argv[]) {
 	number=atoi(line);
 	if (del) {
 	  if (delete_file(sockfd,number)<0) {
-	    snprintf(MAXS(tmp),"cannot delete file #%d (%s) from server",number,fname);
+	    snprintf(tmp,sizeof(tmp)-1,"cannot delete file #%d (%s) from server",number,fname);
 	    errno=0;
 	    message(prg,'E',prg);
 	  } else {
-	    snprintf(MAXS(tmp),"file #%d (%s) deleted from server",number,fname);
+	    snprintf(tmp,sizeof(tmp)-1,"file #%d (%s) deleted from server",number,fname);
 	    if (quiet<2) message(prg,'I',tmp);
 	    n++;
 	  }
@@ -666,7 +666,7 @@ int main(int argc, char *argv[]) {
   for (i=optind;i<argc;i++) {
     listf=rfopen(listfile,"r");
     if (!listf) {
-      snprintf(MAXS(tmp),"cannot open %s for reading",listfile);
+      snprintf(tmp,sizeof(tmp)-1,"cannot open %s for reading",listfile);
       message(prg,'F',tmp);
     }
     while (fgetl(line,listf)) {
@@ -683,11 +683,11 @@ int main(int argc, char *argv[]) {
 	number=atoi(line);
 	if (del) {
 	  if (delete_file(sockfd,number)<0) {
-	    snprintf(MAXS(tmp),"cannot delete file #%d (%s) from server",number,fname);
+	    snprintf(tmp,sizeof(tmp)-1,"cannot delete file #%d (%s) from server",number,fname);
 	    errno=0;
 	    message(prg,'E',prg);
 	  } else {
-	    snprintf(MAXS(tmp),"file #%d (%s) deleted from server",number,fname);
+	    snprintf(tmp,sizeof(tmp)-1,"file #%d (%s) deleted from server",number,fname);
 	    if (quiet<2) message(prg,'I',tmp);
 	    n++;
 	  }
@@ -751,7 +751,7 @@ void rexit(int n) {
     
     /* change back to starting directory */
     if (chdir(swd)<0) {
-      snprintf(MAXS(tmp),"cannot change back to %s",swd);
+      snprintf(tmp,sizeof(tmp)-1,"cannot change back to %s",swd);
       message(prg,'E',tmp);
     } else 
       if (verbose) printf("shell-call: %s\n",rfilen);
@@ -776,7 +776,7 @@ int delete_file(int sockfd, int number) {
   char line[MAXLEN]; 	/* one line of text */
 
   /* send LIST command */
-  snprintf(MAXS(line),"DEL %d",number);
+  snprintf(line,sizeof(line)-1,"DEL %d",number);
   sock_putline(sockfd,line);
   
   sock_getline(sockfd,line);
@@ -827,7 +827,7 @@ int get_list(int sockfd, const char *server, const char *id, FILE *listf) {
     /* invalid answer? */
     if (!str_beq(line,"250")) {
       errno=0;
-      snprintf(MAXS(tmp),"invalid answer from server: %s",line+4);
+      snprintf(tmp,sizeof(tmp)-1,"invalid answer from server: %s",line+4);
       message(prg,'E',tmp);
       return(n);
     }
@@ -956,14 +956,14 @@ int get_file(int sockfd, int number, int ptso) {
     if (!id) message(prg,'F',"cannot create local spool file");
   
     /* open spool header and data files */
-    snprintf(MAXS(shfile),"%d.h",id);
-    snprintf(MAXS(sdfile),"%d.d",id);
+    snprintf(shfile,sizeof(shfile)-1,"%d.h",id);
+    snprintf(sdfile,sizeof(sdfile)-1,"%d.d",id);
     sdfd=open(sdfile,O_WRONLY|O_CREAT,S_IRUSR|S_IWUSR);
     shfd=open(shfile,O_WRONLY|O_CREAT,S_IRUSR|S_IWUSR);
     if (shfd<0 || sdfd<0) message(prg,'F',"cannot create local spool file");
   }
   
-  snprintf(MAXS(tmp),"GET HEADER %d",number);
+  snprintf(tmp,sizeof(tmp)-1,"GET HEADER %d",number);
   sock_putline(sockfd,tmp);
   
   for (;;) {
@@ -981,7 +981,7 @@ int get_file(int sockfd, int number, int ptso) {
 	unlink(shfile);
       }
       errno=0;
-      snprintf(MAXS(tmp),"server-error: %s",line+4);
+      snprintf(tmp,sizeof(tmp)-1,"server-error: %s",line+4);
       message(prg,'E',tmp);
       return(-1);
     }
@@ -1003,7 +1003,7 @@ int get_file(int sockfd, int number, int ptso) {
     if (str_beq(line+4,"FROM")) {
       if ((cp=strchr(line+10,' '))) {
 	*cp=0;
-	snprintf(MAXS(tmp),"%s (%s)",line+9,cp+1);
+	snprintf(tmp,sizeof(tmp)-1,"%s (%s)",line+9,cp+1);
 	*cp=' ';
       } else
 	strcpy(tmp,line+9);
@@ -1050,15 +1050,15 @@ int get_file(int sockfd, int number, int ptso) {
 
   if (quiet<2) {
     if (flp && flp->csize==offset) {
-      snprintf(MAXS(tmp),"file %d (%s) has been already fetched",number,fname);
+      snprintf(tmp,sizeof(tmp)-1,"file %d (%s) has been already fetched",number,fname);
       message(prg,'I',tmp);
     } else {
       if (quiet==1) {
 	if (offset)
-	  snprintf(MAXS(tmp),"resuming fetching file %d (%s) with %ld kB",
+	  snprintf(tmp,sizeof(tmp)-1,"resuming fetching file %d (%s) with %ld kB",
 		   number,fname,(size+1023)/1024);
 	else
-	  snprintf(MAXS(tmp),"fetching file %d (%s) with %ld kB",
+	  snprintf(tmp,sizeof(tmp)-1,"fetching file %d (%s) with %ld kB",
 		   number,fname,(size+1023)/1024);
 	message(prg,'I',tmp);
       }
@@ -1072,7 +1072,7 @@ int get_file(int sockfd, int number, int ptso) {
     return(0);
   }
   
-  snprintf(MAXS(tmp),"GET FILE %d %ld",number,offset);
+  snprintf(tmp,sizeof(tmp)-1,"GET FILE %d %ld",number,offset);
   sock_putline(sockfd,tmp);
   sock_getline(sockfd,line);
 
@@ -1084,7 +1084,7 @@ int get_file(int sockfd, int number, int ptso) {
       unlink(shfile);
     }
     errno=0;
-    snprintf(MAXS(tmp),"server-error: %s",line+4);
+    snprintf(tmp,sizeof(tmp)-1,"server-error: %s",line+4);
     message(prg,'E',tmp);
     return(-1);
   }
@@ -1096,7 +1096,7 @@ int get_file(int sockfd, int number, int ptso) {
   
   /* resend active? */
   if (offset && quiet<2) {
-    snprintf(MAXS(tmp),"resuming at byte %ld",offset);
+    snprintf(tmp,sizeof(tmp)-1,"resuming at byte %ld",offset);
     message("",'I',tmp);
   }
 
@@ -1154,10 +1154,10 @@ int get_file(int sockfd, int number, int ptso) {
     if (quiet==1) {
       
       if (thruput>9999)
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "transfer of %s completed: %.1f kB/s",fname,thruput/1024);
       else
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "transfer of %s completed: %d byte/s",fname,(int)thruput);
       message("",'I',tmp);
 
@@ -1204,10 +1204,10 @@ void init() {
   printf("\nThis is the init routine for %s.\n",prg);
   printf("It will create the necessary pgp files and the spool directory.\n");
   printf("You can press Ctrl-C at any time to stop this procedure.\n\n");
-  snprintf(MAXS(userspool),SPOOL"/%s",pwe->pw_name);
+  snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pwe->pw_name);
   if (stat(userspool,&finfo)<0 || !(finfo.st_mode&S_IFDIR)) {
     printf("User spool %s does not exist.\n",userspool);
-    snprintf(MAXS(userspool),"%s/.sfspool",pwe->pw_dir);
+    snprintf(userspool,sizeof(userspool)-1,"%s/.sfspool",pwe->pw_dir);
     printf("May I create local spool %s? ",userspool);
     fgetl(answer,stdin);
     if (*answer!='y' && *answer!='Y') {
@@ -1233,7 +1233,7 @@ void init() {
   }
 
   if (!(outf=rfopen(configf,"a"))) {
-    snprintf(MAXS(tmp),"cannot open %s",configf);
+    snprintf(tmp,sizeof(tmp)-1,"cannot open %s",configf);
     message(prg,'F',tmp);
   }
   printf("What is the address of your SAFT server where you want to "
@@ -1299,11 +1299,11 @@ int sendfiled_test(const char *user) {
   if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) return(-1);
    
   /* test if you can receive messages */
-  snprintf(MAXS(line),"FROM %s",user);
+  snprintf(line,sizeof(line)-1,"FROM %s",user);
   sock_putline(sockfd,line);
   sock_getline(sockfd,line);
   if (!str_beq(line,"200 ")) return(-1);
-  snprintf(MAXS(line),"TO %s",user);
+  snprintf(line,sizeof(line)-1,"TO %s",user);
   sock_putline(sockfd,line);
   sock_getline(sockfd,line);
   if (!str_beq(line,"200 ")) return(-1);
diff --git a/src/io.c b/src/io.c
index 7e5814c..e011165 100644
--- a/src/io.c
+++ b/src/io.c
@@ -132,7 +132,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
 
   /* get the original file size */
   if (stat(from,&finfo)<0) {
-    snprintf(MAXS(tmp),"cannot access '%s'",from);
+    snprintf(tmp,sizeof(tmp)-1,"cannot access '%s'",from);
     message("",'E',tmp);
     return(-1);
   }
@@ -147,7 +147,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
   /* open source file */
   fdin=open(from,O_RDONLY|O_LARGEFILE,0);
   if (fdin<0) {
-    snprintf(MAXS(tmp),"error opening '%s'",from);
+    snprintf(tmp,sizeof(tmp)-1,"error opening '%s'",from);
     message("",'E',tmp);
     return(-1);
   }
@@ -158,7 +158,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
     /* open destination file */
     fdout=creat(to,mode);
     if (fdout<0) {
-      snprintf(MAXS(tmp),"error creating '%s'",to);
+      snprintf(tmp,sizeof(tmp)-1,"error creating '%s'",to);
       message("",'E',tmp);
       close(fdin);
       return(-1);
@@ -180,7 +180,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
 	close(fdin);
 	close(fdout);
 	free(buf);
-	snprintf(MAXS(tmp),"error writing '%s'",to);
+	snprintf(tmp,sizeof(tmp)-1,"error writing '%s'",to);
 	message("",'E',tmp);
 	return(-1);
       }
@@ -212,7 +212,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
 
   /* read error? */
   if (rbytes<0) {
-    snprintf(MAXS(tmp),"error reading '%s'",from);
+    snprintf(tmp,sizeof(tmp)-1,"error reading '%s'",from);
     message("",'E',tmp);
     return(-1);
   }
@@ -220,7 +220,7 @@ int fcopy(const char *from, const char *to, mode_t mode) {
   /* count mismatch or read/write errors? */
   if (fsize!=wtotal) {
     errno=0;
-    snprintf(MAXS(tmp),"wrong byte count for '%s'",from);
+    snprintf(tmp,sizeof(tmp)-1,"wrong byte count for '%s'",from);
     message("",'E',tmp);
     return(-1);
   }
@@ -334,12 +334,12 @@ char *mktmpdir(int verbose) {
   strcat(tmpdir,tmp);
   
   if (mkdir(tmpdir,S_IRWXU)<0 || chmod(tmpdir,S_IRWXU)<0) {
-    snprintf(MAXS(tmp),"cannot create tmpdir %s",tmpdir);
+    snprintf(tmp,sizeof(tmp)-1,"cannot create tmpdir %s",tmpdir);
     message("",'F',tmp);
   }
   
   if (verbose) {
-    snprintf(MAXS(tmp),"directory for temporary files is: %s",tmpdir);
+    snprintf(tmp,sizeof(tmp)-1,"directory for temporary files is: %s",tmpdir);
     message("",'I',tmp);
   }
   
@@ -365,7 +365,7 @@ void rmtmpdir(char *tmpdir) {
   /* open dir */
   if (chdir(tmpdir) < 0 || !(dp=opendir(tmpdir))) {
     /*
-    snprintf(MAXS(tmp),"cleanup: cannot open %s",tmpdir);
+    snprintf(tmp,sizeof(tmp)-1,"cleanup: cannot open %s",tmpdir);
     message("",'X',tmp);
      */
     return;
@@ -378,7 +378,7 @@ void rmtmpdir(char *tmpdir) {
 
     /* delete file */
     if (unlink(dire->d_name) < 0) {
-      snprintf(MAXS(tmp),"cannot remove %s/%s",tmpdir,dire->d_name);
+      snprintf(tmp,sizeof(tmp)-1,"cannot remove %s/%s",tmpdir,dire->d_name);
       message("",'W',tmp);
     }
     
@@ -386,7 +386,7 @@ void rmtmpdir(char *tmpdir) {
 
   chdir(cwd);
   if (rmdir(tmpdir) < 0) {
-    snprintf(MAXS(tmp),"cannot remove %s",tmpdir);
+    snprintf(tmp,sizeof(tmp)-1,"cannot remove %s",tmpdir);
     message("",'X',tmp);
   }
   
@@ -483,7 +483,7 @@ int vsystem(const char *cmd) {
   extern char *prg;
   
   if (verbose) {
-    snprintf(MAXS(tmp),"shell-call: %s\n",cmd);
+    snprintf(tmp,sizeof(tmp)-1,"shell-call: %s\n",cmd);
     message(prg,'I',tmp);
   }
   return(system(cmd));
@@ -506,8 +506,8 @@ FILE* vpopen(const char *cmd, const char *type) {
   if (verbose) {
     *tmp = 0;
     switch (*type) {
-      case 'r': snprintf(MAXS(tmp),"shell-call: %s|",cmd); break;
-      case 'w': snprintf(MAXS(tmp),"shell-call: |%s",cmd); break;
+      case 'r': snprintf(tmp,sizeof(tmp)-1,"shell-call: %s|",cmd); break;
+      case 'w': snprintf(tmp,sizeof(tmp)-1,"shell-call: |%s",cmd); break;
     }
     message(prg,'I',tmp);
   }
diff --git a/src/net.c b/src/net.c
index eed63ac..64fcbcf 100644
--- a/src/net.c
+++ b/src/net.c
@@ -458,7 +458,7 @@ int sock_getline(int fd, char *line) {
   if (n+1==MAXLEN && line[n] != '\n') {
     if (client) {
       errno=0;
-      snprintf(MAXS(tmp),"network socket data overrun (read bytes: %d)",n);
+      snprintf(tmp,sizeof(tmp)-1,"network socket data overrun (read bytes: %d)",n);
       message("",'E',tmp);
       message("",'F',line);
     }
@@ -530,7 +530,7 @@ char *getreply(int fd) {
       if (len<0) {
 	errno=0;
 	strcpy(msg,"server has closed the connection");
-	if (*reply) snprintf(MAXS(msg),"%s, last data: \"%s\"",msg,reply);
+	if (*reply) snprintf(msg,sizeof(msg)-1,"%s, last data: \"%s\"",msg,reply);
 	if (client) {
 	  errno=0;
 	  message("",'F',msg);
@@ -542,7 +542,7 @@ char *getreply(int fd) {
       /* reply message too short? */
       if (len<4) {
 	errno=0;
-	snprintf(MAXS(msg),"corrupt reply: \"%s\"",reply);
+	snprintf(msg,sizeof(msg)-1,"corrupt reply: \"%s\"",reply);
 	if (client) {
 	  errno=0;
           if (xonf) {
@@ -565,7 +565,7 @@ char *getreply(int fd) {
   /* fatal server error? */
   if (reply[0]=='4') {
     errno=0;
-    snprintf(MAXS(msg),"server error: %s",&reply[4]);
+    snprintf(msg,sizeof(msg)-1,"server error: %s",&reply[4]);
     if (client) {
       errno=0;
       if (xonf) {
@@ -640,7 +640,7 @@ int sendheader(int fd, char *line) {
   if (str_beq(reply,"202")) return(1);
   
   errno=0;
-  snprintf(MAXS(msg),"server error: %s",&reply[4]);
+  snprintf(msg,sizeof(msg)-1,"server error: %s",&reply[4]);
   message(prg,'F',msg);
   		    
   return(-1);
@@ -725,7 +725,7 @@ int send_data(int sockfd, off_t size, const char *file,
 	if (!str_beq(reply,"230 ")) {
 	  if (quiet<3) {
 	    errno=0;
-	    snprintf(MAXS(tmp),"server error: %s",&reply[4]);
+	    snprintf(tmp,sizeof(tmp)-1,"server error: %s",&reply[4]);
 	    message("",'F',tmp);
 	  }
 	  return(-1);
@@ -742,7 +742,7 @@ int send_data(int sockfd, off_t size, const char *file,
 
     /* file already transmitted? */
     if (str_beq(reply,"531 ")) {
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "file %s has been already transmitted - ignored.",iso_name);
       if (quiet<2) message("",'W',tmp);
       return(1);
@@ -751,7 +751,7 @@ int send_data(int sockfd, off_t size, const char *file,
     /* server reply ok? */
     if (!str_beq(reply,"302 ")) {
       if (quiet<3) {
-	snprintf(MAXS(tmp),"corrupt server reply: %s",&reply[4]);
+	snprintf(tmp,sizeof(tmp)-1,"corrupt server reply: %s",&reply[4]);
 	errno=0;
 	message("",'F',tmp);
       }
@@ -764,7 +764,7 @@ int send_data(int sockfd, off_t size, const char *file,
     ffd=open(file,O_RDONLY,0);
     if (ffd<0 || lseek(ffd,offset,SEEK_SET)<0) {
       if (quiet<3) {
-	snprintf(MAXS(tmp),"error reading %s",iso_name);
+	snprintf(tmp,sizeof(tmp)-1,"error reading %s",iso_name);
 	message("",'E',tmp);
       }
       return(-1);
@@ -775,12 +775,12 @@ int send_data(int sockfd, off_t size, const char *file,
 
   /* resend active? */
   if (offset) {
-    snprintf(MAXS(tmp),"resuming %s at byte %lld",iso_name,offset);
+    snprintf(tmp,sizeof(tmp)-1,"resuming %s at byte %lld",iso_name,offset);
     if (quiet<2) message("",'I',tmp);
   }
 
   if (quiet==1) {
-    snprintf(MAXS(tmp),"begin transfer of %s with %lld bytes",fname,size);
+    snprintf(tmp,sizeof(tmp)-1,"begin transfer of %s with %lld bytes",fname,size);
     message("",'I',tmp);
   }
 
@@ -805,7 +805,7 @@ int send_data(int sockfd, off_t size, const char *file,
     if (readn(ffd,packet,packet_size)<packet_size) {
       if (quiet<3) {
         if (!quiet) printf("\n");
-	snprintf(MAXS(tmp),"error reading %s",iso_name);
+	snprintf(tmp,sizeof(tmp)-1,"error reading %s",iso_name);
 	message("",'E',tmp);
       }
       close(ffd);
@@ -844,7 +844,7 @@ int send_data(int sockfd, off_t size, const char *file,
   if ((n=size-nblocks*packet_size) > 0) {
     if (readn(ffd,packet,n)<n) {
       if (quiet<3) {
-        snprintf(MAXS(tmp),"error reading %s",iso_name);
+        snprintf(tmp,sizeof(tmp)-1,"error reading %s",iso_name);
 	message("",'E',tmp);
       }
       close(ffd);
@@ -882,10 +882,10 @@ int send_data(int sockfd, off_t size, const char *file,
     if (quiet==1) {
       
       if (thruput>9999)
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "transfer of %s completed: %.1f kB/s",fname,thruput/1024);
       else
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "transfer of %s completed: %d byte/s",fname,(int)thruput);
       message("",'I',tmp);
 
@@ -909,7 +909,7 @@ int send_data(int sockfd, off_t size, const char *file,
   /* transfer ok? */
   if (sockfd && !str_beq(getreply(sockfd),"201 ")) {
     if (quiet<3) {
-      snprintf(MAXS(tmp),"transfer failed for %s",iso_name);
+      snprintf(tmp,sizeof(tmp)-1,"transfer failed for %s",iso_name);
       errno=0;
       message("",'E',tmp);
     }
diff --git a/src/receive.c b/src/receive.c
index 50ae63e..96501b1 100644
--- a/src/receive.c
+++ b/src/receive.c
@@ -287,11 +287,11 @@ int main(int argc, char *argv[]) {
         case 'q': quiet=1; break;
         case 'p': preserve=1; break;
         case 'H': header=1; break;
-        case 'S': snprintf(MAXS(pgpring),"%s",optarg); break;
+        case 'S': snprintf(pgpring,sizeof(pgpring)-1,"%s",optarg); break;
         case 'v': opt_v="-v"; verbose=1; break;
-        case 'f': snprintf(MAXS(from),"%s",optarg); break;
-        case 'b': snprintf(MAXS(bounce),"%s",optarg); break;
-        case 'Z': snprintf(MAXS(userspool),"%s",optarg); break;
+        case 'f': snprintf(from,sizeof(from)-1,"%s",optarg); break;
+        case 'b': snprintf(bounce,sizeof(bounce)-1,"%s",optarg); break;
+        case 'Z': snprintf(userspool,sizeof(userspool)-1,"%s",optarg); break;
         case 'V': message(prg,'I',"version "VERSION" revision "REVISION"");
 	          exit(0);
     }
@@ -318,18 +318,18 @@ int main(int argc, char *argv[]) {
   /* determine the spool directory */
   if (!*userspool) {
     if ((cp=getenv("SF_SPOOL"))) {
-      snprintf(MAXS(userspool),"%s",cp);
+      snprintf(userspool,sizeof(userspool)-1,"%s",cp);
     } else {
-      snprintf(MAXS(userspool),"%s/.sfspool",pwe->pw_dir);
+      snprintf(userspool,sizeof(userspool)-1,"%s/.sfspool",pwe->pw_dir);
       if (stat(userspool,&finfo)<0 || !(finfo.st_mode&S_IFDIR))
-	snprintf(MAXS(userspool),SPOOL"/%s",pwe->pw_name);
+	snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pwe->pw_name);
     }
   }
-  if (*userspool=='Z') snprintf(MAXS(userspool),SPOOL"/%s",pwe->pw_name);
+  if (*userspool=='Z') snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pwe->pw_name);
 
   /* does the spool directory exist? */
   if (stat(userspool,&finfo)<0 || (finfo.st_mode&S_IFMT)!=S_IFDIR) {
-    snprintf(MAXS(tmp),"spool directory %s does not exist",userspool);
+    snprintf(tmp,sizeof(tmp)-1,"spool directory %s does not exist",userspool);
     errno=0;
     message(prg,'E',tmp);
     exit(1);
@@ -337,7 +337,7 @@ int main(int argc, char *argv[]) {
 
   /* correct permissions for the spool directory? */
   if (!(finfo.st_mode&S_IRWXU) || finfo.st_uid!=getuid()) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "no access to spool directory %s (wrong permissions)",
 	     userspool);
     errno=0;
@@ -348,7 +348,7 @@ int main(int argc, char *argv[]) {
   /* are there any files to receive? */
   sls=scanspool(from);
   if (sls==NULL) {
-    snprintf(MAXS(tmp),"no files found in spool directory %s",userspool);
+    snprintf(tmp,sizeof(tmp)-1,"no files found in spool directory %s",userspool);
     message(prg,'W',tmp);
     exit(1);
   }
@@ -359,7 +359,7 @@ int main(int argc, char *argv[]) {
   }
 
   /* set log file read status (st_atime) for xhoppel */
-  snprintf(MAXS(tmp),"%s/log",userspool);
+  snprintf(tmp,sizeof(tmp)-1,"%s/log",userspool);
   inf=rfopen(tmp,"r");
   if (inf) {
     fgetl(tmp,inf);
@@ -420,15 +420,15 @@ int main(int argc, char *argv[]) {
 
   /* set tmp file names */
   tmpdir=mktmpdir(strlen(opt_v));
-  snprintf(MAXS(tartmp),"%s/receive.tar",tmpdir);
-  snprintf(MAXS(fileslist),"%s/files",tmpdir);
-  snprintf(MAXS(error_log),"%s/error.log",tmpdir);
+  snprintf(tartmp,sizeof(tartmp)-1,"%s/receive.tar",tmpdir);
+  snprintf(fileslist,sizeof(fileslist)-1,"%s/files",tmpdir);
+  snprintf(error_log,sizeof(error_log)-1,"%s/error.log",tmpdir);
 
 
   /* list files? */
   if (listformat) {
     if (list(sls,listformat,from,pgpring,number,argc,argv)<0) {
-      snprintf(MAXS(tmp),"no files in spool directory %s",userspool);
+      snprintf(tmp,sizeof(tmp)-1,"no files in spool directory %s",userspool);
       message(prg,'W',tmp);
     }
     cleanup();
@@ -456,10 +456,10 @@ int main(int argc, char *argv[]) {
 	      delete_sf(flp,1);
 	    else if (*bounce) {
 	      if (*bouncelist) {
-		snprintf(MAXS(tmp),"%s %d",bouncelist,id);
+		snprintf(tmp,sizeof(tmp)-1,"%s %d",bouncelist,id);
 		strcpy(bouncelist,tmp);
 	      } else {
-		snprintf(MAXS(bouncelist),"%d",id);
+		snprintf(bouncelist,sizeof(bouncelist)-1,"%d",id);
 	      }
 	    } else {
 	      receive_sf(flp,pgpring,header);
@@ -473,7 +473,7 @@ int main(int argc, char *argv[]) {
 
       /* not found? */
       if (!found && id) {
-        snprintf(MAXS(tmp),"spool file #%d not found",id);
+        snprintf(tmp,sizeof(tmp)-1,"spool file #%d not found",id);
 	message(prg,'W',tmp);
 	status=1;
       }
@@ -509,10 +509,10 @@ int main(int argc, char *argv[]) {
 	      delete_sf(flp,1);
 	    else if (*bounce) {
 	      if (*bouncelist) {
-		snprintf(MAXS(tmp),"%s %d",bouncelist,flp->id);
+		snprintf(tmp,sizeof(tmp)-1,"%s %d",bouncelist,flp->id);
 		strcpy(bouncelist,tmp);
 	      } else
-		snprintf(MAXS(bouncelist),"%d",flp->id);
+		snprintf(bouncelist,sizeof(bouncelist)-1,"%d",flp->id);
 	    } else
 	      receive_sf(flp,pgpring,header);
 
@@ -524,7 +524,7 @@ int main(int argc, char *argv[]) {
 
       /* not found? */
       if (!found && !all) {
-        snprintf(MAXS(tmp),"file %s not found",pattern);
+        snprintf(tmp,sizeof(tmp)-1,"file %s not found",pattern);
 	message(prg,'W',tmp);
 	status=1;
       }
@@ -537,10 +537,10 @@ int main(int argc, char *argv[]) {
   /* files to bounce? */
   if (*bounce && *bouncelist) {
     if (keep)
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "sendfile -bk=y %s %s %s",opt_v,bouncelist,bounce);
     else
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "sendfile -bk=n %s %s %s",opt_v,bouncelist,bounce);
     vsystem(tmp);
   }
@@ -668,17 +668,17 @@ int list(struct senderlist *sls, int format, char *from, char *pgpring,
 	 
 	  /* encrypted, compressed or normal tar file? */
 	  if (flp->flags&F_CRYPT)
-	    snprintf(MAXS(showtar),"%s %s -f < %s/%d.d | %s tvf -",
+	    snprintf(showtar,sizeof(showtar)-1,"%s %s -f < %s/%d.d | %s tvf -",
 		      pgp_bin,pgpvm,userspool,flp->id,tar_bin);
 	  else if (flp->flags&F_COMPRESS) {
 	    if (str_eq(flp->compress,S_BZIP2))
-	      snprintf(MAXS(showtar),"%s -d < %s/%d.d | %s tvf -",
+	      snprintf(showtar,sizeof(showtar)-1,"%s -d < %s/%d.d | %s tvf -",
 		       bzip2_bin,userspool,flp->id,tar_bin);
 	    else
-	      snprintf(MAXS(showtar),"%s -d < %s/%d.d | %s tvf -",
+	      snprintf(showtar,sizeof(showtar)-1,"%s -d < %s/%d.d | %s tvf -",
 		       gzip_bin,userspool,flp->id,tar_bin);
 	  } else {
-	    snprintf(MAXS(showtar),"%s tvf %s/%d.d",tar_bin,userspool,flp->id);
+	    snprintf(showtar,sizeof(showtar)-1,"%s tvf %s/%d.d",tar_bin,userspool,flp->id);
 	  }
 
 	  /* sneak inside... */
@@ -760,16 +760,16 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
   if (*pgpring) {
     switch (check_signature(flp,pgpring,0)) {
 	case 1:  break;
-	case 0:  snprintf(MAXS(tmp),"no signature found for '%s'",nname);
+	case 0:  snprintf(tmp,sizeof(tmp)-1,"no signature found for '%s'",nname);
                  errno=0;
                  message(prg,'E',tmp);
                  return;
-	case -1: snprintf(MAXS(tmp),"no public key found to check "
+	case -1: snprintf(tmp,sizeof(tmp)-1,"no public key found to check "
 			  "signature for '%s'",nname);
                  errno=0;
                  message(prg,'E',tmp);
                  return;
-	case -2: snprintf(MAXS(tmp),"bad signature for '%s'",nname);
+	case -2: snprintf(tmp,sizeof(tmp)-1,"bad signature for '%s'",nname);
                  errno=0;
                  message(prg,'E',tmp);
 		 return;
@@ -785,7 +785,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 
   /* show only the header? */
   if (header) {
-    snprintf(MAXS(tmp),"%s/%d.h",userspool,flp->id);
+    snprintf(tmp,sizeof(tmp)-1,"%s/%d.h",userspool,flp->id);
     printf("%d) %s\n",flp->id,nname);
     inf=rfopen(tmp,"r");
     while (fgetl(line,inf)) printf("%s",line);
@@ -799,10 +799,10 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     
     /* encrypted spool file? */
     if (flp->flags&F_CRYPT) {
-      snprintf(MAXS(cmd),"%s %s -f < %s/%d.d",pgp_bin,pgpvm,userspool,flp->id);
+      snprintf(cmd,sizeof(cmd)-1,"%s %s -f < %s/%d.d",pgp_bin,pgpvm,userspool,flp->id);
       if (vsystem(cmd)!=0) {
         errno=0;
-	snprintf(MAXS(tmp),"cannot decrypt '%s' :",nname);
+	snprintf(tmp,sizeof(tmp)-1,"cannot decrypt '%s' :",nname);
 	message(prg,'E',tmp);
 	return;
       }
@@ -810,12 +810,12 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     /* compressed spool file? */
     else if (flp->flags&F_COMPRESS) {
       if (str_eq(flp->compress,S_BZIP2))
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d",bzip2_bin,userspool,flp->id);
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d",bzip2_bin,userspool,flp->id);
       else
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d",gzip_bin,userspool,flp->id);
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d",gzip_bin,userspool,flp->id);
       if (vsystem(cmd)!=0 && !(flp->flags&F_TAR)) {
         errno=0;
-	snprintf(MAXS(tmp),"cannot decompress '%s' :",nname);
+	snprintf(tmp,sizeof(tmp)-1,"cannot decompress '%s' :",nname);
 	message(prg,'E',tmp);
 	return;
       }
@@ -823,10 +823,10 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     else /* copy spool file to stdout */ {
       
       /* copy file */
-      snprintf(MAXS(tmp),"%s/%d.d",userspool,flp->id);
+      snprintf(tmp,sizeof(tmp)-1,"%s/%d.d",userspool,flp->id);
       if (fcopy(tmp,"",0)<0) {
         errno=0;
-	snprintf(MAXS(tmp),"cannot read '%s'",nname);
+	snprintf(tmp,sizeof(tmp)-1,"cannot read '%s'",nname);
         message(prg,'E',tmp);
 	return;
       }
@@ -865,9 +865,9 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       if (!quiet && checkfile(utf,fname,nname,sname,&overwrite)) return;
 
       /* copy file */
-      snprintf(MAXS(tmp),"%s/%d.d",userspool,flp->id);
+      snprintf(tmp,sizeof(tmp)-1,"%s/%d.d",userspool,flp->id);
       if (fcopy(tmp,fname,0666&~cmask)<0) {
-        snprintf(MAXS(tmp),"cannot receive '%s'",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot receive '%s'",nname);
 	errno=0;
         message(prg,'E',tmp);
 	return;
@@ -877,7 +877,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       create_sigfile(flp->sign,fname,nname,&overwrite);
 
       if (!keep) delete_sf(flp,0);
-      snprintf(MAXS(tmp),"'%s' received",nname);
+      snprintf(tmp,sizeof(tmp)-1,"'%s' received",nname);
       message(prg,'I',tmp);
 
       return;
@@ -886,14 +886,14 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     /* encrypted tar spool file? */
     if (flp->flags&F_CRYPT) {
       
-      snprintf(MAXS(cmd),"%s %s -f < %s/%d.d > %s",
+      snprintf(cmd,sizeof(cmd)-1,"%s %s -f < %s/%d.d > %s",
 	      pgp_bin,pgpvm,userspool,flp->id,tartmp);
 
       /* create temporary decrypted tar file */
       vsystem(cmd);
       if (stat(tartmp,&finfo)<0 || finfo.st_size==0) {
         errno=0;
-	snprintf(MAXS(tmp),"cannot decrypt '%s' :",nname);
+	snprintf(tmp,sizeof(tmp)-1,"cannot decrypt '%s' :",nname);
 	message(prg,'E',tmp);
 	return;
       }
@@ -914,15 +914,15 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     /* compressed, encrypted or normal tar file? */
     if (flp->flags&F_COMPRESS) {
       if (str_eq(flp->compress,S_BZIP2))
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s tvf -",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s tvf -",
 		 bzip2_bin,userspool,flp->id,tar_bin);
       else
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s tvf -",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s tvf -",
 		 gzip_bin,userspool,flp->id,tar_bin);
     } else if (flp->flags&F_CRYPT) {
-      snprintf(MAXS(cmd),"%s tvf %s",tar_bin,tartmp);
+      snprintf(cmd,sizeof(cmd)-1,"%s tvf %s",tar_bin,tartmp);
     } else {
-      snprintf(MAXS(cmd),"%s tvf %s/%d.d",tar_bin,userspool,flp->id);
+      snprintf(cmd,sizeof(cmd)-1,"%s tvf %s/%d.d",tar_bin,userspool,flp->id);
     }
 
     /* open pipe to read tar file-info */
@@ -949,15 +949,15 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     /* compressed, encrypted or normal tar file? */
     if (flp->flags&F_COMPRESS) {
       if (str_eq(flp->compress,S_BZIP2))
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s tf -",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s tf -",
 		 bzip2_bin,userspool,flp->id,tar_bin);
       else
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s tf -",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s tf -",
 		 gzip_bin,userspool,flp->id,tar_bin);
     } else if (flp->flags&F_CRYPT) {
-      snprintf(MAXS(cmd),"%s tf %s",tar_bin,tartmp);
+      snprintf(cmd,sizeof(cmd)-1,"%s tf %s",tar_bin,tartmp);
     } else {
-      snprintf(MAXS(cmd),"%s tf %s/%d.d",tar_bin,userspool,flp->id);
+      snprintf(cmd,sizeof(cmd)-1,"%s tf %s/%d.d",tar_bin,userspool,flp->id);
     }
 
     /* open pipe to read tar file-info */
@@ -1016,21 +1016,21 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     }
 
     /* receive from tar file */
-    snprintf(MAXS(tmp),"receiving from archive '%s' :",nname);
+    snprintf(tmp,sizeof(tmp)-1,"receiving from archive '%s' :",nname);
     message(prg,'I',tmp);
 
     /* compressed, encrypted or normal tar file? */
     if (flp->flags&F_COMPRESS) {
       if (str_eq(flp->compress,S_BZIP2))
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s xvf - 2>%s",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s xvf - 2>%s",
 		 bzip2_bin,userspool,flp->id,tar_bin,error_log);
       else
-	snprintf(MAXS(cmd),"%s -d < %s/%d.d | %s xvf - 2>%s",
+	snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d | %s xvf - 2>%s",
 		 gzip_bin,userspool,flp->id,tar_bin,error_log);
     } else if (flp->flags&F_CRYPT)
-      snprintf(MAXS(cmd),"%s xvf %s 2>%s",tar_bin,tartmp,error_log);
+      snprintf(cmd,sizeof(cmd)-1,"%s xvf %s 2>%s",tar_bin,tartmp,error_log);
     else
-      snprintf(MAXS(cmd),"%s xvf %s/%d.d 2>%s",
+      snprintf(cmd,sizeof(cmd)-1,"%s xvf %s/%d.d 2>%s",
 	       tar_bin,userspool,flp->id,error_log);
 
     /* receive tar archive and check for errors */
@@ -1044,7 +1044,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 	    !simplematch(line,TAR": Could not create symlink*File exists*",1)) {
 	  if (!terr) {
 	    terr=1;
-	    snprintf(MAXS(tmp),"errors while receive '%s' :",nname);
+	    snprintf(tmp,sizeof(tmp)-1,"errors while receive '%s' :",nname);
 	    message(prg,'E',tmp);
 	  }
 	  printf("%s",line);
@@ -1055,7 +1055,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 
     /* was there an error with tar? */
     if (terr) {
-      snprintf(MAXS(tmp),"leaving '%s' in spool intact",nname);
+      snprintf(tmp,sizeof(tmp)-1,"leaving '%s' in spool intact",nname);
       message(prg,'I',tmp);
     } else {
      
@@ -1108,7 +1108,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
   /* safety fallback: try to delete an old file with the same name */
   unlink(fname);
   if (stat(fname,&finfo)==0) {
-    snprintf(MAXS(tmp),"cannot create '%s' : "
+    snprintf(tmp,sizeof(tmp)-1,"cannot create '%s' : "
 	     "file does already exist and is not deletable",fname);
     errno=0;
     message(prg,'E',tmp);
@@ -1119,16 +1119,16 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
   if (preserve && flp->flags&F_CRYPT) {
    
     /* copy file */
-    snprintf(MAXS(tmp),"%s/%d.d",userspool,flp->id);
+    snprintf(tmp,sizeof(tmp)-1,"%s/%d.d",userspool,flp->id);
     if (fcopy(tmp,fname,0666&~cmask)<0) {
-      snprintf(MAXS(tmp),"cannot receive '%s'",nname);
+      snprintf(tmp,sizeof(tmp)-1,"cannot receive '%s'",nname);
       errno=0;
       message(prg,'E',tmp);
       return;
     }
 
     if ((flp->flags&F_SOURCE || flp->flags&F_TEXT) && !quiet) {
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "'%s' has a SOURCE or TEXT attribute, you have to decode it "
 	       "after pgp-decrypting with:  recode %s:"CHARSET" '%s'",
 	       nname,flp->charset,nname);
@@ -1136,7 +1136,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     }
 
     if (flp->flags&F_MIME && !quiet) {
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "'%s' has the MIME attribute, you have to run it through"
 	       "metamail after pgp-decrypting",nname);
       message(prg,'W',tmp);
@@ -1146,7 +1146,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     create_sigfile(flp->sign,fname,nname,&overwrite);
 
     if (!keep) delete_sf(flp,0);
-    snprintf(MAXS(tmp),"'%s' received",nname);
+    snprintf(tmp,sizeof(tmp)-1,"'%s' received",nname);
     message(prg,'I',tmp);
 
     return;
@@ -1161,11 +1161,11 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       /* open pipe to uncompress or decrypt spool file */
       if (flp->flags&F_COMPRESS) {
 	if (str_eq(flp->compress,S_BZIP2))
-	  snprintf(MAXS(cmd),"%s -d < %s/%d.d",bzip2_bin,userspool,flp->id);
+	  snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d",bzip2_bin,userspool,flp->id);
 	else
-	  snprintf(MAXS(cmd),"%s -d < %s/%d.d",gzip_bin,userspool,flp->id);
+	  snprintf(cmd,sizeof(cmd)-1,"%s -d < %s/%d.d",gzip_bin,userspool,flp->id);
       } else if (flp->flags&F_CRYPT)
-	  snprintf(MAXS(cmd),
+	  snprintf(cmd,sizeof(cmd)-1,
 		   "%s %s -f < %s/%d.d",pgp_bin,pgpvm,userspool,flp->id);
       if ((pp=vpopen(cmd,"r")) == NULL) {
         message(prg,'E',"cannot open spool file for reading");
@@ -1176,7 +1176,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       if (!(outf=rfopen(fname,"w"))) {
 	pclose(pp);
 	printf("\n"); 
-	snprintf(MAXS(tmp),"cannot open '%s' for writing",nname);
+	snprintf(tmp,sizeof(tmp)-1,"cannot open '%s' for writing",nname);
         message(prg,'E',tmp);
         return;
       }
@@ -1192,12 +1192,12 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 
     } else  /* binary format */ {
      
-      snprintf(MAXS(sfile),"%s/%d.d",userspool,flp->id);
+      snprintf(sfile,sizeof(sfile)-1,"%s/%d.d",userspool,flp->id);
 
       /* try to create destination file */
       /* open output file */
       if (!(outf=rfopen(fname,"w"))) {
-        snprintf(MAXS(tmp),"cannot open '%s' for writing",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot open '%s' for writing",nname);
         message(prg,'E',tmp);
         return;
       }
@@ -1215,16 +1215,16 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 	    *++cp=0;
 	  else
 	    *tmp=0;
-	  snprintf(MAXS(tmpfile),"%sreceive-%d.tmp",tmp,(int)getpid());
-	  snprintf(MAXS(tmp),"%s -d < %s > %s",bzip2_bin,sfile,tmpfile);
+	  snprintf(tmpfile,sizeof(tmpfile)-1,"%sreceive-%d.tmp",tmp,(int)getpid());
+	  snprintf(tmp,sizeof(tmp)-1,"%s -d < %s > %s",bzip2_bin,sfile,tmpfile);
 	  if (vsystem(tmp)) {
-	    snprintf(MAXS(tmp),"call to %s failed, cannot receive '%s'",
+	    snprintf(tmp,sizeof(tmp)-1,"call to %s failed, cannot receive '%s'",
 		     bzip2_bin,nname);
 	    message(prg,'E',tmp); 
 	    return;
 	  }
 	  if (rename(tmpfile,fname)<0) {
-	    snprintf(MAXS(tmp),"cannot write to '%s'",nname);
+	    snprintf(tmp,sizeof(tmp)-1,"cannot write to '%s'",nname);
 	    message(prg,'E',tmp); 
 	    unlink(tmpfile);
 	    return;
@@ -1239,7 +1239,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 
 	  if (spawn(sad,fname,cmask)<0) {
 	    errno=0;
-	    snprintf(MAXS(tmp),
+	    snprintf(tmp,sizeof(tmp)-1,
 		     "call to %s failed, cannot receive '%s'",sad[0],nname);
 	    message(prg,'E',tmp); 
 	    return;
@@ -1252,10 +1252,10 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       /* encrypted spool file? */
       if (flp->flags&F_CRYPT) {
        
-	snprintf(MAXS(cmd),"%s %s -f < %s > '%s'",pgp_bin,pgpvm,sfile,fname);
+	snprintf(cmd,sizeof(cmd)-1,"%s %s -f < %s > '%s'",pgp_bin,pgpvm,sfile,fname);
 	if (vsystem(cmd)!=0) {
 	  errno=0;
-	  snprintf(MAXS(tmp),"cannot receive '%s', pgp failed",nname);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot receive '%s', pgp failed",nname);
 	  message(prg,'E',tmp);
 	  unlink(fname);
 	  return;
@@ -1274,7 +1274,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
        !(flp->flags&F_CRYPT)) {
      
       /* open input file */
-      snprintf(MAXS(sfile),"%s/%d.d",userspool,flp->id);
+      snprintf(sfile,sizeof(sfile)-1,"%s/%d.d",userspool,flp->id);
       if ((inf=rfopen(sfile,"r")) == NULL) {
         message(prg,'E',"cannot open spool file for reading");
         return;
@@ -1282,7 +1282,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
 
       /* open output file */
       if ((outf=rfopen(fname,"w")) == NULL) {
-        snprintf(MAXS(tmp),"cannot open '%s' for writing",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot open '%s' for writing",nname);
         message(prg,'E',tmp);
         fclose(inf);
         return;
@@ -1298,9 +1298,9 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     } else   /* binary file */ {
      
       /* copy file */
-      snprintf(MAXS(tmp),"%s/%d.d",userspool,flp->id);
+      snprintf(tmp,sizeof(tmp)-1,"%s/%d.d",userspool,flp->id);
       if (fcopy(tmp,fname,0666&~cmask)<0) {
-        snprintf(MAXS(tmp),"cannot receive '%s'",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot receive '%s'",nname);
 	errno=0;
         message(prg,'E',tmp);
 	return;
@@ -1315,20 +1315,20 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
   /* executable flag set? */
   if (flp->flags&F_EXE) chmod(fname,(S_IRWXU|S_IRWXG|S_IRWXO)&~cmask);
 
-  snprintf(MAXS(tmp),"'%s' received",nname);
+  snprintf(tmp,sizeof(tmp)-1,"'%s' received",nname);
   message(prg,'I',tmp);
 
   /* foreign character set in text file? */
   if ((flp->flags&F_TEXT) && !str_eq(flp->charset,CHARSET)) {
    
     /* call GNU recode */
-    snprintf(MAXS(tmp),"%s:"CHARSET,flp->charset);
+    snprintf(tmp,sizeof(tmp)-1,"%s:"CHARSET,flp->charset);
     sad[0]=recode_bin;
     sad[1]=tmp;
     sad[2]=fname;
     sad[3]=NULL;
     if (spawn(sad,NULL,cmask)<0) {
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "call to %s failed, cannot translate character set in '%s'",
 	       recode_bin,nname);
       message(prg,'E',tmp);
@@ -1348,7 +1348,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
     
     /* metamail call allowed? */
     if (nometamail) {
-      snprintf(MAXS(tmp),
+      snprintf(tmp,sizeof(tmp)-1,
 	       "'%s' is a MIME file, you have to run it through metamail",
 	       nname);
       message(prg,'I',tmp);
@@ -1360,7 +1360,7 @@ void receive_sf(struct filelist *flp, char *pgpring, int header) {
       sad[1]=fname;
       sad[2]=NULL;
       if (spawn(sad,NULL,cmask)<0) {
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "call to %s failed, keeping local file '%s'",
 		 metamail_bin,nname);
 	message(prg,'E',tmp);
@@ -1403,7 +1403,7 @@ void crlf2lf(FILE *inf, FILE *outf, const char *fname, const char *nname) {
      
       /* write lf */
       if(fputc(c2,outf)==EOF) {
-        snprintf(MAXS(tmp),"cannot write to %s",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot write to %s",nname);
         message(prg,'E',tmp);
         return;
       }
@@ -1415,7 +1415,7 @@ void crlf2lf(FILE *inf, FILE *outf, const char *fname, const char *nname) {
      
       /* write char */
       if(fputc(c1,outf)==EOF) {
-        snprintf(MAXS(tmp),"cannot write to %s",nname);
+        snprintf(tmp,sizeof(tmp)-1,"cannot write to %s",nname);
         message(prg,'E',tmp);
         return;
       }
@@ -1426,7 +1426,7 @@ void crlf2lf(FILE *inf, FILE *outf, const char *fname, const char *nname) {
 
   /* write last char */
   if(fputc(c1,outf)==EOF) {
-    snprintf(MAXS(tmp),"cannot write to %s",nname);
+    snprintf(tmp,sizeof(tmp)-1,"cannot write to %s",nname);
     message(prg,'E',tmp);
     return;
   }
@@ -1607,8 +1607,8 @@ int create_sigfile(const char *sign, const char *fname, const char *nname,
   /* no pgp signature to save? */
   if (!*sign) return(0);
 
-  snprintf(MAXS(sigfile),"%s.sig",fname);
-  snprintf(MAXS(nsigfile),"%s.sig",nname);
+  snprintf(sigfile,sizeof(sigfile)-1,"%s.sig",fname);
+  snprintf(nsigfile,sizeof(nsigfile)-1,"%s.sig",nname);
 
   /* signature file does already exist? */
   while (stat(sigfile,&finfo)==0 && (*overwrite!='Y')) {
@@ -1641,7 +1641,7 @@ int create_sigfile(const char *sign, const char *fname, const char *nname,
   /* safety fallback: try to delete an old file with the same name */
   unlink(fname);
   if (stat(sigfile,&finfo)==0) {
-    snprintf(MAXS(tmp),"cannot create '%s' : "
+    snprintf(tmp,sizeof(tmp)-1,"cannot create '%s' : "
 	     "file does already exist and is not deletable",sigfile);
     errno=0;
     message(prg,'E',tmp);
@@ -1649,14 +1649,14 @@ int create_sigfile(const char *sign, const char *fname, const char *nname,
   }
 
   if (!(outf=rfopen(sigfile,"w"))) {
-    snprintf(MAXS(tmp),"cannot create signature file '%s' ",nsigfile);
+    snprintf(tmp,sizeof(tmp)-1,"cannot create signature file '%s' ",nsigfile);
     message(prg,'E',tmp);
     return(-1);
   }
 
   fprintf(outf,"%s",sign);
   fclose(outf);
-  snprintf(MAXS(tmp),"signature file '%s' created",nsigfile);
+  snprintf(tmp,sizeof(tmp)-1,"signature file '%s' created",nsigfile);
   message(prg,'I',tmp);
   return(0);
 
@@ -1695,9 +1695,9 @@ int check_signature(struct filelist *flp, char *pgpring, int print) {
   if (str_eq(pgpring,".")) *pgpring=0;
   
   /* write signature file */
-  snprintf(MAXS(sigfile),"%s/%d.d.sig",userspool,flp->id);
+  snprintf(sigfile,sizeof(sigfile)-1,"%s/%d.d.sig",userspool,flp->id);
   if (!(outf=rfopen(sigfile,"w"))) {
-    snprintf(MAXS(tmp),"cannot write signature file %s",sigfile);
+    snprintf(tmp,sizeof(tmp)-1,"cannot write signature file %s",sigfile);
     message(prg,'E',tmp);
     return(-2);
   }
@@ -1707,15 +1707,15 @@ int check_signature(struct filelist *flp, char *pgpring, int print) {
   /* build pgp options */
   if (*pgpring) {
     if (access(pgpring,R_OK)<0) {
-      snprintf(MAXS(tmp),"cannot read pgp pub ring file %s",pgpring);
+      snprintf(tmp,sizeof(tmp)-1,"cannot read pgp pub ring file %s",pgpring);
       message(prg,'F',tmp);
     }
-    snprintf(MAXS(pgpopt),"+batchmode=on +language=en +pubring=%s",pgpring);
+    snprintf(pgpopt,sizeof(pgpopt)-1,"+batchmode=on +language=en +pubring=%s",pgpring);
   } else
-    snprintf(MAXS(pgpopt),"+batchmode=on +language=en");
+    snprintf(pgpopt,sizeof(pgpopt)-1,"+batchmode=on +language=en");
   
   /* check signature file with pgp */
-  snprintf(MAXS(tmp),"%s %s %s 2>/dev/null",pgp_bin,pgpopt,sigfile);
+  snprintf(tmp,sizeof(tmp)-1,"%s %s %s 2>/dev/null",pgp_bin,pgpopt,sigfile);
   if (!(pp=vpopen(tmp,"r"))) {
     message(prg,'E',"cannot call pgp");
     unlink(sigfile);
@@ -1789,7 +1789,7 @@ void renumber (struct senderlist *sls) {
   max = nextfree = 1;
   
   if (chdir(userspool)<0) {
-    snprintf(MAXS(tmp),"cannot change to %s",userspool);
+    snprintf(tmp,sizeof(tmp)-1,"cannot change to %s",userspool);
     message(prg,'F',tmp);
   }
 
@@ -1816,20 +1816,20 @@ void renumber (struct senderlist *sls) {
     while (fscanf(lockf,"%d\n",&i)!=EOF) {
       if (i<min && i>lastused && i>nextfree) min=i;
     }
-    snprintf(MAXS(ofile),"%d.h",min);
+    snprintf(ofile,sizeof(ofile)-1,"%d.h",min);
     for (i=nextfree; i<min; i++) {
-      snprintf(MAXS(nfile),"%d.h",i);
+      snprintf(nfile,sizeof(nfile)-1,"%d.h",i);
       if (stat(nfile,&finfo)<0 || finfo.st_size==0) {
 	unlink(nfile);
 	if (rename(ofile,nfile)<0) {
-	  snprintf(MAXS(tmp),"cannot rename %s to %s",ofile,nfile);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot rename %s to %s",ofile,nfile);
 	  message(prg,'F',tmp);
 	}
-	snprintf(MAXS(nfile),"%d.d",i);
-	snprintf(MAXS(ofile),"%d.d",min);
+	snprintf(nfile,sizeof(nfile)-1,"%d.d",i);
+	snprintf(ofile,sizeof(ofile)-1,"%d.d",min);
 	unlink(nfile);
 	if (rename(ofile,nfile)<0) {
-	  snprintf(MAXS(tmp),"cannot rename %s to %s",ofile,nfile);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot rename %s to %s",ofile,nfile);
 	  message(prg,'F',tmp);
 	}
 	nextfree=i+1;
diff --git a/src/sendfile.c b/src/sendfile.c
index 9f84393..09f9f52 100644
--- a/src/sendfile.c
+++ b/src/sendfile.c
@@ -651,7 +651,7 @@ const char
     if (strstr(force_compress,"gzip"))  compress=S_GZIP;
     if (strstr(force_compress,"bzip2")) compress=S_BZIP2;
     if (!*compress) {
-      snprintf(MAXS(tmp),"unsupported compression program %s",force_compress);
+      snprintf(tmp,sizeof(tmp)-1,"unsupported compression program %s",force_compress);
       errno=0;
       message(prg,'F',tmp);
     }
@@ -660,7 +660,7 @@ const char
   } else if (*compress) {
 
 #if 0
-    snprintf(MAXS(tmp),"%s --help 2>&1",bzip2_bin);
+    snprintf(tmp,sizeof(tmp)-1,"%s --help 2>&1",bzip2_bin);
     if ((pp=popen(tmp,"r"))) {
       while (fgetl(line,pp)) {
 	if (strstr(line,"usage:")) {
@@ -678,7 +678,7 @@ const char
     }
     if (!*zprg) *bzip2_bin=0;
 	
-    snprintf(MAXS(tmp),"%s --help 2>&1",gzip_bin);
+    snprintf(tmp,sizeof(tmp)-1,"%s --help 2>&1",gzip_bin);
     if ((pp=popen(tmp,"r"))) {
       while (fgetl(line,pp)) if (strstr(line,"usage:")) break;
       pclose(pp);
@@ -719,7 +719,7 @@ const char
   if (str_eq(host,"127.0.0.1") || str_eq(host,"0")) strcpy(host,localhost);
 
   if (*aopt) {
-    snprintf(MAXS(cmd),"%s %s ",argv[0],aopt);
+    snprintf(cmd,sizeof(cmd)-1,"%s %s ",argv[0],aopt);
     for(i=1;i<argc-1;i++) {
       strcat(cmd,"'");
       strcat(cmd,argv[i]);
@@ -764,7 +764,7 @@ const char
 	  pgpcrypt='e';
 	  compress="";
 	  pop++;
-	  snprintf(MAXS(pgprid),"%s@%s",recipient,host);
+	  snprintf(pgprid,sizeof(pgprid)-1,"%s@%s",recipient,host);
 
 	  /* is there a recipient id? */
 	  if (*pop>'\n') {
@@ -796,7 +796,7 @@ const char
 	  /* is there a signature id? */
 	  if (*pop>'\n') {
 	    if (*pop=='=') pop++;
-	    snprintf(MAXS(pgpsign),"-u '%s",pop);
+	    snprintf(pgpsign,sizeof(pgpsign)-1,"-u '%s",pop);
 
 	    /* cut off any more options */
 	    if ((cp=strchr(pgpsign,'\n'))) {
@@ -813,7 +813,7 @@ const char
 
 	/* wrong pgp options */
 	errno=0;
-	snprintf(MAXS(tmp),"wrong pgp option, see 'man %s'",prg);
+	snprintf(tmp,sizeof(tmp)-1,"wrong pgp option, see 'man %s'",prg);
 	message(prg,'F',tmp);
 
       }
@@ -821,13 +821,13 @@ const char
   }
 
   /* set various file names */
-  snprintf(MAXS(userspool),SPOOL"/%s",pw_name);
-  snprintf(MAXS(outlogtmp),"%s/.sendfile_%d.log",userspool,pid);
-  snprintf(MAXS(tartmp),"%s/sendfile.tar",tmpdir);
-  snprintf(MAXS(ziptmp),"%s/sendfile.zip",tmpdir);
-  snprintf(MAXS(pgptmp),"%s/sendfile.pgp",tmpdir);
-  snprintf(MAXS(texttmp),"%s/sendfile.txt",tmpdir);
-  snprintf(MAXS(stdintmp),"%s/sendfile.tmp",tmpdir);
+  snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pw_name);
+  snprintf(outlogtmp,sizeof(outlogtmp)-1,"%s/.sendfile_%d.log",userspool,pid);
+  snprintf(tartmp,sizeof(tartmp)-1,"%s/sendfile.tar",tmpdir);
+  snprintf(ziptmp,sizeof(ziptmp)-1,"%s/sendfile.zip",tmpdir);
+  snprintf(pgptmp,sizeof(pgptmp)-1,"%s/sendfile.pgp",tmpdir);
+  snprintf(texttmp,sizeof(texttmp)-1,"%s/sendfile.txt",tmpdir);
+  snprintf(stdintmp,sizeof(stdintmp)-1,"%s/sendfile.tmp",tmpdir);
 
   /* where are the files/directories ? */
   if (*where) {
@@ -845,11 +845,11 @@ const char
       if (quiet)
 	printf("%s\n",userspool);
       else {
-	snprintf(MAXS(tmp),"the user spool directory is: %s",userspool);
+	snprintf(tmp,sizeof(tmp)-1,"the user spool directory is: %s",userspool);
 	message(prg,'I',tmp);
       } 
     } else {
-      snprintf(MAXS(tmp),"%s is an unknown -W argument",where);
+      snprintf(tmp,sizeof(tmp)-1,"%s is an unknown -W argument",where);
       errno=0;
       message(prg,'E',tmp);
       if (quiet<2) message(prg,'I',"you may specify -W=config, -W=spool, or "
@@ -865,27 +865,27 @@ const char
   unlink(pgptmp);
   unlink(stdintmp);
   if (stat(tartmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",tartmp);
     message(prg,'F',tmp);
   }
   if (stat(ziptmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",ziptmp);
     message(prg,'F',tmp);
   }
   if (stat(texttmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",texttmp);
     message(prg,'F',tmp);
   }
   if (stat(pgptmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",pgptmp);
     message(prg,'F',tmp);
   }
   if (stat(stdintmp,&finfo)==0) {
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "tmp-file %s does already exist and cannot be deleted",stdintmp);
     message(prg,'F',tmp);
   }
@@ -954,7 +954,7 @@ const char
   /* set tcp packet length */
   if (packet_size<1) packet_size=PACKET;
   if (verbose && !spool && !del) {
-    snprintf(MAXS(tmp),"packet size = %d bytes",packet_size);
+    snprintf(tmp,sizeof(tmp)-1,"packet size = %d bytes",packet_size);
     message(prg,'I',tmp);
   }
 
@@ -970,14 +970,14 @@ const char
    
     /* write stdin to tmp-file */
     if (!(outf=rfopen(stdintmp,"w"))) {
-      snprintf(MAXS(tmp),"cannot open tmp-file %s",stdintmp);
+      snprintf(tmp,sizeof(tmp)-1,"cannot open tmp-file %s",stdintmp);
       message(prg,'F',tmp);
     }
     /* while ((ch=getchar())!=EOF) putc(ch,outf); */
     while ((bytes=read(fileno(stdin),iobuf,IOB))) {
       if (bytes<0) message(prg,'F',"error while reading from stdin");
       if (write(fileno(outf),iobuf,bytes)!=bytes) {
-	snprintf(MAXS(tmp),"error while writing stdin to %s",stdintmp);
+	snprintf(tmp,sizeof(tmp)-1,"error while writing stdin to %s",stdintmp);
 	message(prg,'F',tmp);
       }
     }
@@ -1022,13 +1022,13 @@ const char
       /* does the outgoing spool exist? */
       strcpy(outgoing,SPOOL"/OUTGOING");
       if (stat(outgoing,&finfo)<0 || !S_ISDIR(finfo.st_mode)) {
-	snprintf(MAXS(tmp),"spool directory %s does not exist",outgoing);
+	snprintf(tmp,sizeof(tmp)-1,"spool directory %s does not exist",outgoing);
 	message(prg,'F',tmp);
       }
 
       /* and does it have the correct protection? */
       if (!((finfo.st_mode&S_ISVTX) && (finfo.st_mode&S_IRWXO))) {
-	snprintf(MAXS(tmp),
+	snprintf(tmp,sizeof(tmp)-1,
 		 "spool directory %s has wrong protection (must have 1777)",
 		 outgoing);
 	message(prg,'F',tmp);
@@ -1045,19 +1045,19 @@ const char
 
     /* does the spool directory exist? */
     if (chdir(userspool)<0) {
-      snprintf(MAXS(tmp),"cannot access spool directory %s",userspool);
+      snprintf(tmp,sizeof(tmp)-1,"cannot access spool directory %s",userspool);
       message(prg,'F',tmp);
     }
 
     /* main loop over the spool file names */
     for (fn=optind; fn<argc-1; fn++) {
-      snprintf(MAXS(sdfn),"%s.d",argv[fn]);
-      snprintf(MAXS(shfn),"%s.h",argv[fn]);
-      if (info) snprintf(MAXS(tinfo),"#%d/%d: ",fn-optind+1,argc-optind-1);
+      snprintf(sdfn,sizeof(sdfn)-1,"%s.d",argv[fn]);
+      snprintf(shfn,sizeof(shfn)-1,"%s.h",argv[fn]);
+      if (info) snprintf(tinfo,sizeof(tinfo)-1,"#%d/%d: ",fn-optind+1,argc-optind-1);
       
       /* try to open spool header file */
       if (!(shf=rfopen(shfn,"r"))) {
-        snprintf(MAXS(tmp),"cannot open spool file #%s",argv[fn]);
+        snprintf(tmp,sizeof(tmp)-1,"cannot open spool file #%s",argv[fn]);
 	message(prg,'E',tmp);
         continue;
       }
@@ -1091,7 +1091,7 @@ const char
 	  strcpy(comment,strchr(line,' ')+1);
 	  if ((cp=strchr(comment,' '))) {
 	    *cp=0;
-	    snprintf(MAXS(tmp),"%s+ACA-(%s)",comment,cp+1);
+	    snprintf(tmp,sizeof(tmp)-1,"%s+ACA-(%s)",comment,cp+1);
 	    strcpy(comment,tmp);
 	  }
 	  continue;
@@ -1129,7 +1129,7 @@ const char
 	    if (str_beq(reply,"200 ")) break;
 	    
 	    /* error! */
-	    snprintf(MAXS(tmp),"cannot send %s : %s",file,reply+4);
+	    snprintf(tmp,sizeof(tmp)-1,"cannot send %s : %s",file,reply+4);
 	    errno=0;
 	    message(prg,'E',tmp);
 	    fclose(inf);
@@ -1142,15 +1142,15 @@ const char
 	    /* recompress spool file */
 	    if (str_eq(type,S_BZIP2)) {
 	      if (str_eq(compress,S_GZIP))
-		snprintf(MAXS(cmd),"%s -d <%s|%s>%s",BZIP2,sdfn,GZIP,ziptmp);
+		snprintf(cmd,sizeof(cmd)-1,"%s -d <%s|%s>%s",BZIP2,sdfn,GZIP,ziptmp);
 	      else
-		snprintf(MAXS(cmd),"%s -d < %s > %s",BZIP2,sdfn,ziptmp);
+		snprintf(cmd,sizeof(cmd)-1,"%s -d < %s > %s",BZIP2,sdfn,ziptmp);
 	    } else
-	      snprintf(MAXS(cmd),"%s -dc %s > %s",GZIP,sdfn,ziptmp);
+	      snprintf(cmd,sizeof(cmd)-1,"%s -dc %s > %s",GZIP,sdfn,ziptmp);
 	    
 	    /* execute shell-command and close spool header file on error */
 	    if (vsystem(cmd)) {
-	      snprintf(MAXS(tmp),"cannot recompress spool file #%s",argv[fn]);
+	      snprintf(tmp,sizeof(tmp)-1,"cannot recompress spool file #%s",argv[fn]);
 	      message(prg,'E',tmp);
 	      fclose(inf);
 	      break;
@@ -1169,9 +1169,9 @@ const char
 	/* is there already a comment line? */
 	if (str_beq(line,"COMMENT")) {
 	  if (*redirect) 
-	    snprintf(MAXS(line),"%s+AA0ACg-%s",comment,redirect);
+	    snprintf(line,sizeof(line)-1,"%s+AA0ACg-%s",comment,redirect);
 	  else {
-	    snprintf(MAXS(tmp),
+	    snprintf(tmp,sizeof(tmp)-1,
 		     "%s+AA0ACg-forward+ACA-from+ACA-%s",line,comment);
 	    strcpy(line,tmp);
 	  }
@@ -1200,9 +1200,9 @@ const char
       /* send comment if not already done */
       if (*comment) {
         iso2utf(tmp,"forward from ");
-	snprintf(MAXS(line),"COMMENT %s%s",tmp,comment);
+	snprintf(line,sizeof(line)-1,"COMMENT %s%s",tmp,comment);
 	if (*redirect) {
-	  snprintf(MAXS(tmp),"\r\n%s",redirect);
+	  snprintf(tmp,sizeof(tmp)-1,"\r\n%s",redirect);
 	  iso2utf(comment,tmp);
 	  strcat(line,comment);
 	}
@@ -1215,12 +1215,12 @@ const char
       /* check the file size */
       if (stat(ziptmp,&finfo)==0) {
 	size=finfo.st_size;
-	snprintf(MAXS(sizes),"%lld %lld",size,orgsize);
-	snprintf(MAXS(line),"SIZE %s",sizes);
+	snprintf(sizes,sizeof(sizes)-1,"%lld %lld",size,orgsize);
+	snprintf(line,sizeof(line)-1,"SIZE %s",sizes);
 	sendcommand(sockfd,line,NULL);
       } else {
 	if (stat(sdfn,&finfo)<0 || size!=finfo.st_size) {
-	  snprintf(MAXS(tmp),
+	  snprintf(tmp,sizeof(tmp)-1,
 		   "spool file #%s has wrong size count - ignored",argv[fn]);
 	  errno=0;
 	  message(prg,'E',tmp);
@@ -1302,7 +1302,7 @@ const char
       fflush(stdout);
     }
     if (verbose) {
-      snprintf(MAXS(tmp),"shell-call: %s",cmd);
+      snprintf(tmp,sizeof(tmp)-1,"shell-call: %s",cmd);
       message(prg,'I',tmp);
     }
 
@@ -1331,9 +1331,9 @@ const char
       /* compress tar-archive */
       if (!quiet) printf("compressing...       \r");
       fflush(stdout);
-      snprintf(MAXS(cmd),"%s < %s > %s",zprg,tartmp,ziptmp);
+      snprintf(cmd,sizeof(cmd)-1,"%s < %s > %s",zprg,tartmp,ziptmp);
       if (verbose) {
-	snprintf(MAXS(tmp),"shell-call: %s",cmd);
+	snprintf(tmp,sizeof(tmp)-1,"shell-call: %s",cmd);
 	message(prg,'I',tmp);
       }
       if (vsystem(cmd)) message(prg,'F',"cannot compress archive file");
@@ -1350,7 +1350,7 @@ const char
     /* get the file size */
     if (stat(file,&finfo)<0) message(prg,'F',"cannot access tmp file");
     size=finfo.st_size;
-    snprintf(MAXS(sizes),"%lld %lld",size,orgsize);
+    snprintf(sizes,sizeof(sizes)-1,"%lld %lld",size,orgsize);
 
     /* write to outgoing spool? */
     if (spool) {
@@ -1360,9 +1360,9 @@ const char
 	 
 	/* create correct to-string */
 	if (strchr(argv[argc-1],'*'))
-	  snprintf(MAXS(to),"%s",argv[argc-1]);
+	  snprintf(to,sizeof(to)-1,"%s",argv[argc-1]);
 	else
-	  snprintf(MAXS(to),"%s@%s",recipient,host);
+	  snprintf(to,sizeof(to)-1,"%s@%s",recipient,host);
 	  
 	/* search for file in outgoing spool */
 	for (hlp=hls; hlp; hlp=hlp->next) {
@@ -1372,7 +1372,7 @@ const char
 	    if (simplematch(oflp->fname,utf_name,0)) {
 		
 	      /* matching recipient? */
-	      snprintf(MAXS(rto),"%s@%s",oflp->to,hlp->host);
+	      snprintf(rto,sizeof(rto)-1,"%s@%s",oflp->to,hlp->host);
 	      if (simplematch(rto,to,0)) {
 		unlink(oflp->oshfn);
 		oflp->oshfn[strlen(oflp->oshfn)-1]='d';
@@ -1406,7 +1406,7 @@ const char
       
     } else { /* send header lines */
 
-      snprintf(MAXS(tmp),"FILE %s",utf_name);
+      snprintf(tmp,sizeof(tmp)-1,"FILE %s",utf_name);
       /* deactivate exit on 4xx error to test for timeout */
       client=0;
       sendcommand(sockfd,tmp,reply);
@@ -1415,7 +1415,7 @@ const char
       /* saft server still online? (check timeout) */
       if (str_beq(reply,"429 ")) {
 	sockfd=saft_connect("file",recipient,user,host,redirect);
-	snprintf(MAXS(tmp),"FILE %s",utf_name);
+	snprintf(tmp,sizeof(tmp)-1,"FILE %s",utf_name);
 	sendcommand(sockfd,tmp,reply);
       }
       
@@ -1424,14 +1424,14 @@ const char
       
       if (overwrite) {
 	if (str_beq(reply,"200 ")) sendcommand(sockfd,"DEL",reply);
-	snprintf(MAXS(tmp),"FILE %s",utf_name);
+	snprintf(tmp,sizeof(tmp)-1,"FILE %s",utf_name);
 	sendcommand(sockfd,tmp,reply);
       }
       if (*compress) {
 	if (str_eq(compress,S_GZIP))
-	  snprintf(MAXS(tmp),"TYPE BINARY COMPRESSED");
+	  snprintf(tmp,sizeof(tmp)-1,"TYPE BINARY COMPRESSED");
 	else
-	  snprintf(MAXS(tmp),"TYPE BINARY COMPRESSED=%s",compress);
+	  snprintf(tmp,sizeof(tmp)-1,"TYPE BINARY COMPRESSED=%s",compress);
 	sendcommand(sockfd,tmp,reply);
 	if (!test && !str_beq(reply,"200 ") && quiet<2) {
 	  errno=0;
@@ -1448,7 +1448,7 @@ const char
 	if (!test && !str_beq(reply,"200 ") && quiet<2) 
 	  message(prg,'W',"remote site does not support binary files");
       }
-      snprintf(MAXS(tmp),"SIZE %s",sizes);
+      snprintf(tmp,sizeof(tmp)-1,"SIZE %s",sizes);
       sendheader(sockfd,tmp);
       sendcommand(sockfd,"ATTR TAR",reply);
       if (!test && !str_beq(reply,"200 ") && quiet<2) {
@@ -1463,7 +1463,7 @@ const char
       if (*comment) strcat(line,comment);
       if (*redirect) {
         if (*line) {
-	  snprintf(MAXS(tmp),"%s\r\n%s",line,redirect);
+	  snprintf(tmp,sizeof(tmp)-1,"%s\r\n%s",line,redirect);
 	  strcpy(line,tmp);
 	} else
 	  strcpy(line,redirect);
@@ -1472,7 +1472,7 @@ const char
       if (spool)
 	fprintf(oshf,"COMMENT\t%s\n",tmp);
       else {
-        snprintf(MAXS(line),"COMMENT %s",tmp);
+        snprintf(line,sizeof(line)-1,"COMMENT %s",tmp);
 	sendcommand(sockfd,line,NULL);
       }
     }
@@ -1515,7 +1515,7 @@ const char
    
     /* main loop over the file names */
     for (fn=optind; fn<argc-1; fn++) {
-      if (info) snprintf(MAXS(tinfo),"#%d/%d: ",fn-optind+1,argc-optind-1);
+      if (info) snprintf(tinfo,sizeof(tinfo)-1,"#%d/%d: ",fn-optind+1,argc-optind-1);
      
       /* file from stdin? */
       if (stdinf) {
@@ -1549,9 +1549,9 @@ const char
 	 
 	  /* create correct to-string */
 	  if (strchr(argv[argc-1],'*'))
-	    snprintf(MAXS(to),"%s",argv[argc-1]);
+	    snprintf(to,sizeof(to)-1,"%s",argv[argc-1]);
 	  else
-	    snprintf(MAXS(to),"%s@%s",recipient,host);
+	    snprintf(to,sizeof(to)-1,"%s@%s",recipient,host);
 	  
 	  /* search for file in outgoing spool */
 	  for (hlp=hls; hlp; hlp=hlp->next) {
@@ -1561,7 +1561,7 @@ const char
 	      if (simplematch(oflp->fname,utf_name,0)) {
 		
 		/* matching recipient? */
-		snprintf(MAXS(rto),"%s@%s",oflp->to,hlp->host);
+		snprintf(rto,sizeof(rto)-1,"%s@%s",oflp->to,hlp->host);
 		if (simplematch(rto,to,0)) {
 		  unlink(oflp->oshfn);
 		  oflp->oshfn[strlen(oflp->oshfn)-1]='d';
@@ -1569,7 +1569,7 @@ const char
 		  if (del) {
 		    del=2;
 		    utf2iso(0,NULL,file,NULL,oflp->fname);
-		    snprintf(MAXS(tmp),
+		    snprintf(tmp,sizeof(tmp)-1,
 			     "deleted from outgoing spool: '%s' for %s ",
 			     file,rto);
 		    if (quiet<2) message(prg,'I',tmp);
@@ -1595,7 +1595,7 @@ const char
       } else /* send header lines */ {
        
 	/* send file name */
-	snprintf(MAXS(tmp),"FILE %s",utf_name);
+	snprintf(tmp,sizeof(tmp)-1,"FILE %s",utf_name);
 	sendcommand(sockfd,tmp,reply);
 	if (!test && !str_beq(reply,"200 ") && quiet<2) 
 	  message(prg,'W',"remote site does not support file names");
@@ -1606,7 +1606,7 @@ const char
 	  if (sendheader(sockfd,"DEL")) {
 	    if (quiet<2) message(prg,'W',"remote site cannot delete files");
 	  } else {
-	    snprintf(MAXS(tmp),"'%s' deleted",iso_name);
+	    snprintf(tmp,sizeof(tmp)-1,"'%s' deleted",iso_name);
 	    if (quiet<2) message(prg,'I',tmp);
 	  }
 	  continue;
@@ -1616,7 +1616,7 @@ const char
 
       /* is the file readable? */
       if (stat(file,&finfo)<0) {
-        snprintf(MAXS(tmp),"cannot access '%s'",file);
+        snprintf(tmp,sizeof(tmp)-1,"cannot access '%s'",file);
 	message(prg,'E',tmp);
 	if (spool) {
 	  fclose(oshf);
@@ -1628,7 +1628,7 @@ const char
       /* is it a regular file? */
       if (!S_ISREG(finfo.st_mode)) {
 	errno=0;
-        snprintf(MAXS(tmp),"%s is not a regular file, skipping",file);
+        snprintf(tmp,sizeof(tmp)-1,"%s is not a regular file, skipping",file);
 	message(prg,'E',tmp);
 	if (spool) {
 	  fclose(oshf);
@@ -1659,7 +1659,7 @@ const char
 	inf=rfopen(file,"r");
 	outf=rfopen(texttmp,"w");
 	if (!inf) {
-	  snprintf(MAXS(tmp),"cannot open '%s'",file);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot open '%s'",file);
 	  message(prg,'E',tmp);
 	  if (spool) {
 	    fclose(oshf);
@@ -1703,7 +1703,7 @@ const char
 	for (n=0;do_compress && *cft[n];n++) {
 
 	  /* is this file a not compressible one? */
-	  snprintf(MAXS(tmp),"*%s*",cft[n]);
+	  snprintf(tmp,sizeof(tmp)-1,"*%s*",cft[n]);
 	  if (simplematch(ftype,tmp,1)) do_compress=0;
 
 	}
@@ -1715,13 +1715,13 @@ const char
 	/* compress tmp-file */
 	if (!quiet) printf("compressing...       \r");
 	fflush(stdout);
-	snprintf(MAXS(cmd),"%s < '%s' > %s",zprg,file,ziptmp);
+	snprintf(cmd,sizeof(cmd)-1,"%s < '%s' > %s",zprg,file,ziptmp);
 	if (verbose) {
-	  snprintf(MAXS(tmp),"shell-call: %s",strchr(cmd,';')+1);
+	  snprintf(tmp,sizeof(tmp)-1,"shell-call: %s",strchr(cmd,';')+1);
 	  message(prg,'I',tmp);
 	}
 	if (vsystem(cmd)) {
-	  snprintf(MAXS(tmp),"cannot compress %s",file);
+	  snprintf(tmp,sizeof(tmp)-1,"cannot compress %s",file);
 	  message(prg,'E',tmp);
 	  if (spool) {
 	    fclose(oshf);
@@ -1743,7 +1743,7 @@ const char
       /* get the file size */
       if (stat(file,&finfo)<0) message(prg,'F',"cannot access tmp file");
       size=finfo.st_size;
-      snprintf(MAXS(sizes),"%lld %lld",size,orgsize);
+      snprintf(sizes,sizeof(sizes)-1,"%lld %lld",size,orgsize);
       /*
         printf("DEBUG: size=%lld orgsize=%lld sizes=%s\n",size,orgsize,sizes); 
         exit(0);
@@ -1781,22 +1781,22 @@ const char
        
 	if (do_compress) {
 	  if (str_eq(compress,S_GZIP))
-	    snprintf(MAXS(line),"TYPE %s COMPRESSED",type);
+	    snprintf(line,sizeof(line)-1,"TYPE %s COMPRESSED",type);
 	  else
-	    snprintf(MAXS(line),"TYPE %s COMPRESSED=%s",type,compress);
+	    snprintf(line,sizeof(line)-1,"TYPE %s COMPRESSED=%s",type,compress);
 	} else if (pgpcrypt)
-	  snprintf(MAXS(line),"TYPE %s CRYPTED",type);
+	  snprintf(line,sizeof(line)-1,"TYPE %s CRYPTED",type);
 	else
-	  snprintf(MAXS(line),"TYPE %s",type);
+	  snprintf(line,sizeof(line)-1,"TYPE %s",type);
 	sendcommand(sockfd,line,reply);
 	if (!test && !str_beq(reply,"200 ") && quiet<2) {
 	  errno=0;
-	  snprintf(MAXS(tmp),"remote site does not support file of %s",line);
+	  snprintf(tmp,sizeof(tmp)-1,"remote site does not support file of %s",line);
 	  message(prg,'F',tmp);
 	}
-	snprintf(MAXS(tmp),"SIZE %s",sizes);
+	snprintf(tmp,sizeof(tmp)-1,"SIZE %s",sizes);
 	sendheader(sockfd,tmp);
-	snprintf(MAXS(tmp),"DATE %s",date);
+	snprintf(tmp,sizeof(tmp)-1,"DATE %s",date);
 	if (sendheader(sockfd,tmp) && quiet<2)
 	  message(prg,'W',"remote site does not support dates");
 	if (exe)
@@ -1811,7 +1811,7 @@ const char
 	if (*comment) strcat(line,comment);
 	if (*redirect) {
 	  if (*line) {
-	    snprintf(MAXS(tmp),"%s\r\n%s",line,redirect);
+	    snprintf(tmp,sizeof(tmp)-1,"%s\r\n%s",line,redirect);
 	    strcpy(line,tmp);
 	  } else
 	    strcpy(line,redirect);
@@ -1820,7 +1820,7 @@ const char
 	if (spool)
 	  fprintf(oshf,"COMMENT\t%s\n",tmp);
 	else {
-	  snprintf(MAXS(line),"COMMENT %s",tmp);
+	  snprintf(line,sizeof(line)-1,"COMMENT %s",tmp);
 	  sendcommand(sockfd,line,NULL);
 	}
       }
@@ -1880,15 +1880,15 @@ const char
   if (tsize && info && tfn>1 && quiet<2) {
     thruput=tsize*1000/tttime;
    if (tsize/1024>9999)
-      snprintf(MAXS(tmp),"%d files sent with %.1f MB",tfn,tsize/1024/1024);
+      snprintf(tmp,sizeof(tmp)-1,"%d files sent with %.1f MB",tfn,tsize/1024/1024);
     else if (tsize>9999)
-      snprintf(MAXS(tmp),"%d files sent with %.1f kB",tfn,tsize/1024);
+      snprintf(tmp,sizeof(tmp)-1,"%d files sent with %.1f kB",tfn,tsize/1024);
     else
-      snprintf(MAXS(tmp),"%d files sent with %d byte",tfn,(int)tsize);
+      snprintf(tmp,sizeof(tmp)-1,"%d files sent with %d byte",tfn,(int)tsize);
     if (thruput>9999)
-      snprintf(MAXS(line),"%s at %.1f kB/s",tmp,thruput/1024);
+      snprintf(line,sizeof(line)-1,"%s at %.1f kB/s",tmp,thruput/1024);
     else
-      snprintf(MAXS(line),"%s at %d byte/s",tmp,(int)thruput);
+      snprintf(line,sizeof(line)-1,"%s at %d byte/s",tmp,(int)thruput);
     message("",'I',line);
   }
 
@@ -1952,7 +1952,7 @@ void cleanup() {
       if (str_beq(reply,"220 ") && strstr(reply,"SAFT")) {
 	
 	/* send LOG command */
-	snprintf(MAXS(line),"LOG %s %s",pw_name,outlogtmp);
+	snprintf(line,sizeof(line)-1,"LOG %s %s",pw_name,outlogtmp);
 	sock_putline(sockfd,line);
 	sock_getline(sockfd,reply);
 	str_trim(reply);
@@ -1981,7 +1981,7 @@ void cleanup() {
 	    if (str_beq(reply,"220 ") && strstr(reply,"SAFT")) {
 	      
 	      /* send LOG command */
-	      snprintf(MAXS(line),"LOG %s %s",pw_name,outlogtmp);
+	      snprintf(line,sizeof(line)-1,"LOG %s %s",pw_name,outlogtmp);
 	      sock_putline(sockfd,line);
 	      sock_getline(sockfd,reply);
 	      str_trim(reply);
@@ -2033,7 +2033,7 @@ void pgp_encrypt(int pgpcrypt, char *pgprid, char *file) {
 
   /* look for matching pgp-IDs */
   if (strlen(pgprid)>1) {
-    snprintf(MAXS(cmd),"%s -kvf %s > %s 2>/dev/null",pgp_bin,pgprid,pgptmp);
+    snprintf(cmd,sizeof(cmd)-1,"%s -kvf %s > %s 2>/dev/null",pgp_bin,pgprid,pgptmp);
     vsystem(cmd);
     if (stat(pgptmp,&finfo)<0 || finfo.st_size==0 || !(inf=rfopen(pgptmp,"r"))) {
       errno=0;
@@ -2044,7 +2044,7 @@ void pgp_encrypt(int pgpcrypt, char *pgprid, char *file) {
     if ((cp=strchr(line,'.'))) *cp=0;
     if (!str_eq(line,"1 matching key found")) {
       if (!quiet) {
-	snprintf(MAXS(line),"ambigous pgp-ID '%s'",pgprid);
+	snprintf(line,sizeof(line)-1,"ambigous pgp-ID '%s'",pgprid);
 	message(prg,'W',line);
 	inf=rfopen(pgptmp,"r");
 	while (fgetl(line,inf)) printf("%s",line);
@@ -2057,7 +2057,7 @@ void pgp_encrypt(int pgpcrypt, char *pgprid, char *file) {
 
   /* pgp needs user input? */
   if (pgpcrypt=='c' || !*pgprid) {
-    snprintf(MAXS(cmd),"%s +armor=off -f%c < %s > %s",
+    snprintf(cmd,sizeof(cmd)-1,"%s +armor=off -f%c < %s > %s",
 	     pgp_bin,pgpcrypt,shell_quote(file),pgptmp);
     if (vsystem(cmd) || stat(pgptmp,&finfo)<0 || finfo.st_size==0) {
       errno=0;
@@ -2067,7 +2067,7 @@ void pgp_encrypt(int pgpcrypt, char *pgprid, char *file) {
 
   /* pgp needs no user input */ 
   } else {
-    snprintf(MAXS(cmd),"%s +armor=off -fe %s < %s > %s 2>/dev/null",
+    snprintf(cmd,sizeof(cmd)-1,"%s +armor=off -fe %s < %s > %s 2>/dev/null",
 	     pgp_bin,pgprid,shell_quote(file),pgptmp);
     if (vsystem(cmd) || stat(pgptmp,&finfo)<0 || finfo.st_size==0) {
       errno=0;
@@ -2102,10 +2102,10 @@ void pgp_sign(const char *pgpsign, const char *infile, int sockfd) {
 
   if (!quiet && !pgppass) message(prg,'I',"call to pgp...");
 
-  snprintf(MAXS(cmd),"%s %s -fsba %s < %s",
+  snprintf(cmd,sizeof(cmd)-1,"%s %s -fsba %s < %s",
 	   pgp_bin,pgpvm,pgpsign,shell_quote(infile));
   if (verbose) {
-    snprintf(MAXS(tmp),"shell-call: %s",cmd);
+    snprintf(tmp,sizeof(tmp)-1,"shell-call: %s",cmd);
     message(prg,'I',tmp);
   }
   if (!(pipe=popen(cmd,"r"))) message(prg,'F',"call to pgp (signature) failed");
@@ -2124,7 +2124,7 @@ void pgp_sign(const char *pgpsign, const char *infile, int sockfd) {
   if (check!=3) message(prg,'F',"call to pgp (signature) failed");
 
   iso2utf(tmp,sign);
-  snprintf(MAXS(sign),"SIGN %s",tmp);
+  snprintf(sign,sizeof(sign)-1,"SIGN %s",tmp);
   if (sockfd) sendcommand(sockfd,sign,NULL);
 }
 
@@ -2197,13 +2197,13 @@ void start_spooldaemon(char *localhost) {
 #else
   sockfd=open_connection(localhost,SERVICE);
 #endif
-  if (sockfd==-1) snprintf(MAXS(tmp),"cannot create a network socket "
+  if (sockfd==-1) snprintf(tmp,sizeof(tmp)-1,"cannot create a network socket "
 			      "- cannot start local spool daemon");
-  if (sockfd==-2) snprintf(MAXS(tmp),"cannot open connection to %s "
+  if (sockfd==-2) snprintf(tmp,sizeof(tmp)-1,"cannot open connection to %s "
 			      "- cannot start local spool daemon",localhost);
-  if (sockfd==-3) snprintf(MAXS(tmp),"%s is unknown (name server down?) "
+  if (sockfd==-3) snprintf(tmp,sizeof(tmp)-1,"%s is unknown (name server down?) "
 			      "- cannot start local spool daemon",localhost);
-  if (sockfd==-4) snprintf(MAXS(tmp),"out of memory "
+  if (sockfd==-4) snprintf(tmp,sizeof(tmp)-1,"out of memory "
 			      "- cannot start local spool daemon");
   if (sockfd<0) {
     errno=0;
@@ -2215,10 +2215,10 @@ void start_spooldaemon(char *localhost) {
   if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) {
     errno=0;
 #ifndef ENABLE_MULTIPROTOCOL
-    snprintf(MAXS(tmp),"No SAFT server on port %d at %s "
+    snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %d at %s "
 	        "- cannot start local spool daemon",SAFT,localhost);
 #else
-    snprintf(MAXS(tmp),"No SAFT server on port %s at %s "
+    snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %s at %s "
 	        "- cannot start local spool daemon",SERVICE,localhost);
 #endif
     message(prg,'F',tmp);
@@ -2241,13 +2241,13 @@ void start_spooldaemon(char *localhost) {
 #else
     sockfd=open_connection(host,SERVICE);
 #endif
-    if (sockfd==-1) snprintf(MAXS(tmp),"cannot create a network socket "
+    if (sockfd==-1) snprintf(tmp,sizeof(tmp)-1,"cannot create a network socket "
 			        "- cannot start local spool daemon");
-    if (sockfd==-2) snprintf(MAXS(tmp),"cannot open connection to %s "
+    if (sockfd==-2) snprintf(tmp,sizeof(tmp)-1,"cannot open connection to %s "
 			        "- cannot start local spool daemon",host);
-    if (sockfd==-3) snprintf(MAXS(tmp),"%s is unknown (name server down?) "
+    if (sockfd==-3) snprintf(tmp,sizeof(tmp)-1,"%s is unknown (name server down?) "
 			        "- cannot start local spool daemon",host);
-    if (sockfd==-4) snprintf(MAXS(tmp),"out of memory "
+    if (sockfd==-4) snprintf(tmp,sizeof(tmp)-1,"out of memory "
 			        "- cannot start local spool daemon");
     if (sockfd<0) {
       errno=0;
@@ -2259,10 +2259,10 @@ void start_spooldaemon(char *localhost) {
     if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) {
       errno=0;
 #ifndef ENABLE_MULTIPROTOCOL
-      snprintf(MAXS(tmp),"No SAFT server on port %d at %s "
+      snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %d at %s "
 	          "- cannot start local spool daemon",SAFT,host);
 #else
-      snprintf(MAXS(tmp),"No SAFT server on port %s at %s "
+      snprintf(tmp,sizeof(tmp)-1,"No SAFT server on port %s at %s "
 	          "- cannot start local spool daemon",SERVICE,host);
 #endif
       message(prg,'F',tmp);
@@ -2392,7 +2392,7 @@ void get_header(const char *cmd, char *arg){
   if (!str_eq(cmd,line)) {
     errno=0;
     line[MAXLEN-80]=0;
-    snprintf(MAXS(tmp),
+    snprintf(tmp,sizeof(tmp)-1,
 	     "illegal SAFT command \"%s\", \"%s\" was expected",line,cmd);
     message(prg,'F',tmp);
   }
@@ -2473,7 +2473,7 @@ char guess_ftype(const char *file, char *type) {
   /* next, try with file command */
   
   /* read output from file command */
-  snprintf(MAXS(cmd),"file %s",shell_quote(file));
+  snprintf(cmd,sizeof(cmd)-1,"file %s",shell_quote(file));
   if ((pipe=vpopen(cmd,"r")) && fgetl(tmp,pipe)) {
     pclose(pipe);
     
@@ -2485,7 +2485,7 @@ char guess_ftype(const char *file, char *type) {
     if ((cp=strchr(type,'\n'))) *cp=0;
     
     if (verbose) {
-      snprintf(MAXS(tmp),"%s is of type %s",file,type);
+      snprintf(tmp,sizeof(tmp)-1,"%s is of type %s",file,type);
       message(prg,'I',tmp);
     }
     
@@ -2535,14 +2535,14 @@ int linkspeed(const char *host, int lanspeed, char **compress) {
   if (lanspeed<1) return(1);
   
   /* create speeds dir if necessary */
-  snprintf(MAXS(speeddir),"%s/speeds",userspool);
+  snprintf(speeddir,sizeof(speeddir)-1,"%s/speeds",userspool);
   if (stat(speeddir,&finfo)<0 || !S_ISDIR(finfo.st_mode)) {
     unlink(speeddir);
     if (mkdir(speeddir,S_IRUSR|S_IWUSR|S_IXUSR)<0) return(1);
     chmod(speeddir,S_IRUSR|S_IWUSR|S_IXUSR);
   }
   
-  snprintf(MAXS(hostfile),"%s/%s",speeddir,host);
+  snprintf(hostfile,sizeof(hostfile)-1,"%s/%s",speeddir,host);
 
   /* if host file is missing return slow link */
   if (!(inf=rfopen(hostfile,"r"))) return(1);
@@ -2552,11 +2552,11 @@ int linkspeed(const char *host, int lanspeed, char **compress) {
   if (speed<lanspeed) return(1);
 
   if (verbose) {
-    snprintf(MAXS(msg),
+    snprintf(msg,sizeof(msg)-1,
 	     "disabling compressing because last link speed to %s was %d kB/s",
 	     host,speed);
     message(prg,'I',msg);
-    snprintf(MAXS(msg),"LAN speed is defined as min %d kB/s",lanspeed);
+    snprintf(msg,sizeof(msg)-1,"LAN speed is defined as min %d kB/s",lanspeed);
     message(prg,'I',msg);
   }
 
@@ -2587,14 +2587,14 @@ void notespeed(const char *host, unsigned long size, float ttime) {
   if (ttime<1 || size<102400) return;
     
   /* create speeds dir if necessary */
-  snprintf(MAXS(speeddir),"%s/speeds",userspool);
+  snprintf(speeddir,sizeof(speeddir)-1,"%s/speeds",userspool);
   if (stat(speeddir,&finfo)<0 || !S_ISDIR(finfo.st_mode)) {
     unlink(speeddir);
     if (mkdir(speeddir,S_IRUSR|S_IWUSR|S_IXUSR)<0) return;
     chmod(speeddir,S_IRUSR|S_IWUSR|S_IXUSR);
   }
   
-  snprintf(MAXS(hostfile),"%s/%s",speeddir,host);
+  snprintf(hostfile,sizeof(hostfile)-1,"%s/%s",speeddir,host);
 
   if ((outf=rfopen(hostfile,"w"))) {
     fprintf(outf,"%d\n",(int)(size/ttime/1.024)); /* kB/s */
@@ -2658,7 +2658,7 @@ void spooled_info(const char *file, const char *sdf, int compressed) {
   if (quiet>1) return;
   
   if (stat(sdf,&finfo)<0) {
-    snprintf(MAXS(tmp),"cannot access spool file %s",sdf);
+    snprintf(tmp,sizeof(tmp)-1,"cannot access spool file %s",sdf);
     message(prg,'E',tmp);
     return;
   }
@@ -2666,9 +2666,9 @@ void spooled_info(const char *file, const char *sdf, int compressed) {
   size=(finfo.st_size+512)/1024; 
   
   if (compressed)
-    snprintf(MAXS(tmp),"'%s' spooled (%d KB [compressed])",file,size);
+    snprintf(tmp,sizeof(tmp)-1,"'%s' spooled (%d KB [compressed])",file,size);
   else
-    snprintf(MAXS(tmp),"'%s' spooled (%d KB)",file,size);
+    snprintf(tmp,sizeof(tmp)-1,"'%s' spooled (%d KB)",file,size);
   message(prg,'I',tmp);
 }
 
diff --git a/src/sendfiled.c b/src/sendfiled.c
index eb25612..39715e5 100644
--- a/src/sendfiled.c
+++ b/src/sendfiled.c
@@ -655,7 +655,7 @@ int main(int argc, char *argv[]) {
 	}
 	if (str_eq(line,"path")) {
 	  if (*argp == '/') { 
-	    snprintf(MAXS(path),"PATH=%s",argp);
+	    snprintf(path,sizeof(path)-1,"PATH=%s",argp);
 	    putenv(path);
 	  }
 	  continue;
@@ -665,7 +665,7 @@ int main(int argc, char *argv[]) {
 	  continue;
 	}
 	if (str_eq(line,"forcepgp")) {
-	  snprintf(MAXS(sys_forcepgp),"%s",argp);
+	  snprintf(sys_forcepgp,sizeof(sys_forcepgp)-1,"%s",argp);
 	  continue;
 	}
 	if (str_eq(line,"spooling")) {
@@ -896,7 +896,7 @@ int main(int argc, char *argv[]) {
       strcpy(forcepgp,sys_forcepgp);
 
       /* parse the user config-file */
-      snprintf(MAXS(tmp),"%s/config",userconfig);
+      snprintf(tmp,sizeof(tmp)-1,"%s/config",userconfig);
       setreugid();
       if ((inf=rfopen(tmp,"r"))) {
 	while ((fgetl(line,inf))) {
@@ -935,7 +935,7 @@ int main(int argc, char *argv[]) {
 
 	    /* pgp force option */
 	    if (str_eq(line,"forcepgp")) {
-	      snprintf(MAXS(forcepgp),"%s",argp);
+	      snprintf(forcepgp,sizeof(forcepgp)-1,"%s",argp);
 	      continue;
 	    }
 
@@ -946,7 +946,7 @@ int main(int argc, char *argv[]) {
 	      if (str_beq(argp,"mail"))	   strcpy(notification,"m");
 	      if (str_eq(argp,"both"))	   strcpy(notification,"b");
 	      if (str_eq(argp,"program")) 
-		snprintf(MAXS(notification),"%s/notify ",userconfig);
+		snprintf(notification,sizeof(notification)-1,"%s/notify ",userconfig);
 	      else {
 
 		/* mail address specified to send notifications to? */
@@ -1038,18 +1038,18 @@ int main(int argc, char *argv[]) {
       peer=peername(0);
       if (str_eq(peer,"localhost")) peer=localhost;
       if (strlen(arg)+strlen(peer)+strlen(real)+4<MAXLEN) {
-	snprintf(MAXS(utfsender),"%s@%s %s",arg,peer,real);
-	snprintf(MAXS(tmp),"%s@%s (%s)",arg,peer,real);
+	snprintf(utfsender,sizeof(utfsender)-1,"%s@%s %s",arg,peer,real);
+	snprintf(tmp,sizeof(tmp)-1,"%s@%s (%s)",arg,peer,real);
 	utf2iso(0,sender,NULL,NULL,tmp);
 	if ((cp=strchr(utfsender,' '))) {
 	  *cp=0;
-	  snprintf(MAXS(logsender),"%s (%s)",utfsender,cp+1);
+	  snprintf(logsender,sizeof(logsender)-1,"%s (%s)",utfsender,cp+1);
 	  *cp=' ';
 	} else
 	  strcpy(logsender,utfsender);
       } else {
-	snprintf(MAXS(utfsender),"???@%s",peer);
-	snprintf(MAXS(sender),"???@%s",peer);
+	snprintf(utfsender,sizeof(utfsender)-1,"???@%s",peer);
+	snprintf(sender,sizeof(sender)-1,"???@%s",peer);
       }
 
       reply(200);
@@ -1087,7 +1087,7 @@ int main(int argc, char *argv[]) {
       if ((cp=strchr(date,'T'))) *cp=' ';
       if (!strchr(date,'-')) {
 	strcpy(tmp,date);
-	snprintf(MAXS(date),"%c%c%c%c-%c%c-%c%c %c%c:%c%c:%c%c",
+	snprintf(date,sizeof(date)-1,"%c%c%c%c-%c%c-%c%c %c%c:%c%c:%c%c",
 		tmp[0],tmp[1],tmp[2],tmp[3],
 		tmp[4],tmp[5],
 		tmp[6],tmp[7],
@@ -1402,7 +1402,7 @@ int main(int argc, char *argv[]) {
       timetick=time(0);
       if (bell) strcat(msg,"\007");
       strftime(currentdate,9,"%H:%M",localtime(&timetick));
-      snprintf(MAXS(msgh),"Message from %s at %s :",sender,currentdate);
+      snprintf(msgh,sizeof(msgh)-1,"Message from %s at %s :",sender,currentdate);
 
       /* try to send to recipient ttys */
       if (msg2tty(recipient,msgh,msg,O_SYNC)<0)
@@ -1412,7 +1412,7 @@ int main(int argc, char *argv[]) {
 	/* log sender address */
 	if (rgid) setegid(rgid);
 	if (ruid) seteuid(ruid);
-	snprintf(MAXS(tmp),"%s/msg@%s",userconfig,localhost);
+	snprintf(tmp,sizeof(tmp)-1,"%s/msg@%s",userconfig,localhost);
 	if ((outf=rfopen(tmp,"w"))) {
 	  strcpy(tmp,sender);
 	  if ((cp=strchr(tmp,' '))) *cp=0;
@@ -1566,7 +1566,7 @@ int main(int argc, char *argv[]) {
 
 	  /* open spool data file for appending */
 	  id=flp->id;
-	  snprintf(MAXS(sdfile),"%d.d",id);
+	  snprintf(sdfile,sizeof(sdfile)-1,"%d.d",id);
 	  sdfd=open(sdfile,O_WRONLY|O_APPEND|O_LARGEFILE,S_IRUSR|S_IWUSR);
 	  if (sdfd<0) notify_reply(&notify,notification,sender,recipient,
 				   mailto,bell,412);
@@ -1608,8 +1608,8 @@ int main(int argc, char *argv[]) {
 	    notify_reply(&notify,notification,sender,recipient,mailto,bell,413);
 	  
 	  /* open spool header and data files */
-	  snprintf(MAXS(shfile),"%d.h",id);
-	  snprintf(MAXS(sdfile),"%d.d",id);
+	  snprintf(shfile,sizeof(shfile)-1,"%d.h",id);
+	  snprintf(sdfile,sizeof(sdfile)-1,"%d.d",id);
 	  sdfd=open(sdfile,O_WRONLY|O_CREAT|O_LARGEFILE,S_IRUSR|S_IWUSR);
 	  shfd=open(shfile,O_WRONLY|O_CREAT,S_IRUSR|S_IWUSR);
 	  if (shfd<0 || sdfd<0) notify_reply(&notify,notification,sender,
@@ -1734,7 +1734,7 @@ int main(int argc, char *argv[]) {
 	if (*rpipe) {
 
 	  /* open post-processing pipe */
-	  snprintf(MAXS(tmp),"cat %s/%s %s/%s | %s && rm -f %s/%s %s/%s",
+	  snprintf(tmp,sizeof(tmp)-1,"cat %s/%s %s/%s | %s && rm -f %s/%s %s/%s",
 		   userspool,shfile,
 		   userspool,sdfile,
 		   rpipe,			     
@@ -1817,7 +1817,7 @@ int main(int argc, char *argv[]) {
 		(str_eq(date,flp->date) || !*date) &&
 		flags==flp->flags) {
 	      /* with same sizes? */
-	      snprintf(MAXS(tmp),"%lld %lld",flp->csize,flp->osize);
+	      snprintf(tmp,sizeof(tmp)-1,"%lld %lld",flp->csize,flp->osize);
 	      if (str_eq(tmp,sizes)) {
 
 		/* number of bytes already transmitted */
@@ -1931,14 +1931,14 @@ int main(int argc, char *argv[]) {
       setreugid();
 
       /* write challenge file */
-      snprintf(MAXS(chfile),"tmp_challenge_%d",(int)getpid());
+      snprintf(chfile,sizeof(chfile)-1,"tmp_challenge_%d",(int)getpid());
       outf=rfopen(chfile,"w");
       if (!outf) reply(410);
       fprintf(outf,"%d",challenge);
       fclose(outf);
       
       /* write challenge signature file */
-      snprintf(MAXS(csfile),"tmp_challenge_%d.asc",(int)getpid());
+      snprintf(csfile,sizeof(csfile)-1,"tmp_challenge_%d.asc",(int)getpid());
       unlink(csfile);
       outf=rfopen(csfile,"w");
       if (!outf) {
@@ -1954,7 +1954,7 @@ int main(int argc, char *argv[]) {
  * pgp -sbaf +clearsig=on +secring=private.pgp +pubring=private.pgp
  */
       
-      snprintf(MAXS(tmp),"%s +pubring=config/public.pgp %s %s 2>/dev/null",
+      snprintf(tmp,sizeof(tmp)-1,"%s +pubring=config/public.pgp %s %s 2>/dev/null",
 	       pgp_bin,csfile,chfile);
       pp=popen(tmp,"r");
       if (!pp) {
@@ -2009,7 +2009,7 @@ int main(int argc, char *argv[]) {
       }
       
       /* change to user config directory */
-      snprintf(MAXS(tmp),"%s/config",userspool);
+      snprintf(tmp,sizeof(tmp)-1,"%s/config",userspool);
       if (chdir(tmp)<0) reply(410);
 
       /* change effective uid and gid to recipient */
@@ -2138,7 +2138,7 @@ int main(int argc, char *argv[]) {
 	setreugid();
 
 	/* open header file */
-	snprintf(MAXS(shfile),"%d.h",id);
+	snprintf(shfile,sizeof(shfile)-1,"%d.h",id);
 	if (!(inf=rfopen(shfile,"r"))) reply(550);
 
 	/* read and transfer header file */
@@ -2163,7 +2163,7 @@ int main(int argc, char *argv[]) {
 	setreugid();
 
 	/* open spool data file */
-	snprintf(MAXS(sdfile),"%d.d",id);
+	snprintf(sdfile,sizeof(sdfile)-1,"%d.d",id);
 	if (stat(sdfile,&finfo)<0 || (infd=open(sdfile,O_RDONLY|O_LARGEFILE))<0) reply(550);
 	if (transmitted>finfo.st_size) {
 	  reply(507);
@@ -2434,7 +2434,7 @@ void writeheader(int fd, const char *attribute, const char *value) {
   int hsize;			/* header string size */
   char header[2*MAXLEN];	/* header string */
 
-  snprintf(MAXS(header),"%s\t%s\n",attribute,value);
+  snprintf(header,sizeof(header)-1,"%s\t%s\n",attribute,value);
   hsize=strlen(header);
   if (write(fd,header,hsize)<hsize) reply(412);
 }
@@ -2537,7 +2537,7 @@ int msg2tty(const char *recipient, const char *msgh, char *msg, int mode) {
   /* change effective uid to recipient for security reasons */
   setreugid();
 
-  snprintf(MAXS(msgcf),"%s/config/tty@%s",userspool,localhost);
+  snprintf(msgcf,sizeof(msgcf)-1,"%s/config/tty@%s",userspool,localhost);
 
   /* force writing to all ttys which are open? */
   if (*msg && str_beq(msg,"wall!")) {
@@ -2546,9 +2546,9 @@ int msg2tty(const char *recipient, const char *msgh, char *msg, int mode) {
   }
 
   if (*msg)
-    snprintf(MAXS(output),"\r\n%s\n\r%s\r\n",msgh,msg);
+    snprintf(output,sizeof(output)-1,"\r\n%s\n\r%s\r\n",msgh,msg);
   else
-    snprintf(MAXS(output),"\r\n%s\n\r",msgh);
+    snprintf(output,sizeof(output)-1,"\r\n%s\n\r",msgh);
     
   /* is there a message control file? */
   if (!wall && success<=0 && (inf=rfopen(msgcf,"r"))) {
@@ -2586,7 +2586,7 @@ int msg2tty(const char *recipient, const char *msgh, char *msg, int mode) {
     /* scan through utmp (currently logged in users) */
     while (read(utmpfd,(char *)&uinfo,sizeof(uinfo))>0) {
       
-#if defined(NEXT) || defined(BSD) || defined(ULTRIX) || defined(SOLARIS1)
+#if defined(NEXT) || defined(BSD) || defined(ULTRIX) || defined(SOLARIS1) || defined(__APPLE__)
       strncpy(user,uinfo.ut_name,8);
       if (str_eq(recipient,user)) {
 	
@@ -2598,7 +2598,7 @@ int msg2tty(const char *recipient, const char *msgh, char *msg, int mode) {
       if (uinfo.ut_type==USER_PROCESS && str_eq(recipient,user)) {
 #endif
 	/* get the tty */
-	snprintf(MAXS(tty),"/dev/%s",uinfo.ut_line);
+	snprintf(tty,sizeof(tty)-1,"/dev/%s",uinfo.ut_line);
 
 	/* is the tty writeable? */
 	if (stat(tty,&finfo)==0 &&
@@ -2664,7 +2664,7 @@ void mail2user(const char *recipient, const char *sender, const char *msg) {
   while ((cp=strchr(sender,'\''))) *cp=' ';
 
   /* open pipe to sendmail */
-  snprintf(MAXS(cmd),SENDMAIL" %s",recipient);
+  snprintf(cmd,sizeof(cmd)-1,SENDMAIL" %s",recipient);
   pout=popen(cmd,"w");
 
   /* fill out mail message */
@@ -2730,7 +2730,7 @@ int restricted(const char *sender, const char *recipient, char type) {
 
   setreugid();
   
-  snprintf(MAXS(killfile),"%s/config/restrictions",userspool);
+  snprintf(killfile,sizeof(killfile)-1,"%s/config/restrictions",userspool);
   *kfm=*kfu=0;
 
   /* open and check killfile */
@@ -2786,9 +2786,9 @@ off_t free_space() {
 #endif
 
   if (*userspool)
-    snprintf(MAXS(spool),"%s/.",userspool);
+    snprintf(spool,sizeof(spool)-1,"%s/.",userspool);
   else
-    snprintf(MAXS(spool),"%s/.",SPOOL);
+    snprintf(spool,sizeof(spool)-1,"%s/.",SPOOL);
     
 #if defined(IRIX) || defined(IRIX64)
   if (statfs(spool,&fsinfo,sizeof(struct statfs),0)==0)
@@ -2838,7 +2838,7 @@ int get_sizes(char *string, off_t *size, off_t *osize) {
 
   /* get maximum file size for this process */
 #ifdef RLIMIT_FSIZE
-  if (getrlimit(RLIMIT_FSIZE,&rl)==0) snprintf(MAXS(max),"%llu",rl.rlim_cur);
+  if (getrlimit(RLIMIT_FSIZE,&rl)==0) snprintf(max,sizeof(max)-1,"%llu",rl.rlim_cur);
 #endif    
   
   /* get compressed and original file size string */
@@ -2883,10 +2883,10 @@ int send_msg(const char *msg, const char *to, const char *recipient) {
   cp=strchr(to,'@');
   if (cp) {
     *cp=0;
-    snprintf(MAXS(user),"%s",to);
-    snprintf(MAXS(host),"%s",cp+1);
+    snprintf(user,sizeof(user)-1,"%s",to);
+    snprintf(host,sizeof(host)-1,"%s",cp+1);
   } else {
-    snprintf(MAXS(user),"%s",to);
+    snprintf(user,sizeof(user)-1,"%s",to);
     strcpy(host,localhost);
   }
 
@@ -2901,24 +2901,24 @@ int send_msg(const char *msg, const char *to, const char *recipient) {
   sock_getline(sockfd,line);
   if (!str_beq(line,"220 ") || !strstr(line,"SAFT")) return(-1);
 /*
-  snprintf(MAXS(tmp),"connected to %s",host);
+  snprintf(tmp,sizeof(tmp)-1,"connected to %s",host);
   dbgout(tmp);
 */  
-  snprintf(MAXS(line),"FROM %s autogenerated+ACA-SAFT+ACA-message",recipient);
-  snprintf(MAXS(line),"FROM %s",recipient);
+  snprintf(line,sizeof(line)-1,"FROM %s autogenerated+ACA-SAFT+ACA-message",recipient);
+  snprintf(line,sizeof(line)-1,"FROM %s",recipient);
   sock_putline(sockfd,line);
   if (!str_beq(getreply(sockfd),"200 ")) {
     close(sockfd);
     return(-1);  
   }
-  snprintf(MAXS(line),"TO %s",user);
+  snprintf(line,sizeof(line)-1,"TO %s",user);
   sock_putline(sockfd,line);
   if (!str_beq(getreply(sockfd),"200 ")) {
     close(sockfd);
     return(-1);  
   }
   iso2utf(tmp,(char*)msg);
-  snprintf(MAXS(line),"MSG %s",tmp);
+  snprintf(line,sizeof(line)-1,"MSG %s",tmp);
   sock_putline(sockfd,line);
   if (!str_beq(getreply(sockfd),"200 ")) {
     close(sockfd);
@@ -2978,7 +2978,7 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
   /* test outgoing spool */
   if (chdir(OUTGOING)<0) {
     if (queue==1) message(prg,'F',OUTGOING);
-    snprintf(MAXS(tmp),OUTGOING" : %s",strerror(errno));
+    snprintf(tmp,sizeof(tmp)-1,OUTGOING" : %s",strerror(errno));
     dbgout(tmp);
     exit(1);
   }
@@ -3022,16 +3022,16 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
     /* relock */
     unlink(lockfn);
     if ((lockf=open(lockfn,O_WRONLY|O_CREAT,S_IRUSR|S_IWUSR))<0) {
-      snprintf(MAXS(tmp),"cannot open %s : %s",lockfn,strerror(errno));
+      snprintf(tmp,sizeof(tmp)-1,"cannot open %s : %s",lockfn,strerror(errno));
       dbgout(tmp);
       exit(1);
     }
     if (wlock_file(lockf)<0) {
-      snprintf(MAXS(tmp),"cannot lock %s : %s",lockfn,strerror(errno));
+      snprintf(tmp,sizeof(tmp)-1,"cannot lock %s : %s",lockfn,strerror(errno));
       dbgout(tmp);
       exit(1);
     }
-    snprintf(MAXS(tmp),"%d\n",(int)getpid());
+    snprintf(tmp,sizeof(tmp)-1,"%d\n",(int)getpid());
     write(lockf,tmp,strlen(tmp));
 
     /* disconnect from client */
@@ -3079,7 +3079,7 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
 	  continue;
 	}
 	
-	snprintf(MAXS(tmp),"connected to %s",hlp->host);
+	snprintf(tmp,sizeof(tmp)-1,"connected to %s",hlp->host);
 	if (queue==1) message(prg,'I',tmp);
 	dbgout(tmp);
 	
@@ -3126,7 +3126,7 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
 
 		/* same host? */
 		if (str_eq(hlp->host,ahost)) {
-		  snprintf(MAXS(line),"TO %s",arecipient);
+		  snprintf(line,sizeof(line)-1,"TO %s",arecipient);
 		  sock_putline(sockfd,line);
 		  rs=getreply(sockfd);
 		  if (!str_beq(rs,"200")) {
@@ -3150,7 +3150,7 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
 		  break;
 		}
 		
-		snprintf(MAXS(tmp),"connected to %s (forward redirection)",
+		snprintf(tmp,sizeof(tmp)-1,"connected to %s (forward redirection)",
 			 hlp->host);
 		if (queue==1) message(prg,'I',tmp);
 		dbgout(tmp);
@@ -3252,7 +3252,7 @@ int sfsd(int queue, int parallel, int bounce, int retry, float mtp) {
     while ((ssec=t0-time(0)+retry*60)>0) {
       sigchld();
       signal(SIGCHLD,sigchld);
-      snprintf(MAXS(tmp),"sleep %d s",ssec);
+      snprintf(tmp,sizeof(tmp)-1,"sleep %d s",ssec);
       dbgout(tmp);
       sleep(ssec);
     }
@@ -3291,17 +3291,17 @@ int send_spooldata(int sockfd, char *oshfn, char *from, char *to,
   /* status report */
   if (queue) {
     utf2iso(0,isoname,NULL,NULL,fname);
-    snprintf(MAXS(tmp),"sending %s to %s",isoname,to);
+    snprintf(tmp,sizeof(tmp)-1,"sending %s to %s",isoname,to);
     message(prg,'I',tmp);
   }
 		
-  snprintf(MAXS(tmp),"sending %s to %s@%s",fname,to,host);
+  snprintf(tmp,sizeof(tmp)-1,"sending %s to %s@%s",fname,to,host);
   dbgout(tmp);
 
   strcpy(osdfn,oshfn);
   osdfn[strlen(osdfn)-1]='d';
   if (stat(osdfn,&finfo)<0) {
-    snprintf(MAXS(tmp),"cannot access %s",osdfn);
+    snprintf(tmp,sizeof(tmp)-1,"cannot access %s",osdfn);
     dbgout(tmp);
     return(-1);
   }
@@ -3318,10 +3318,10 @@ int send_spooldata(int sockfd, char *oshfn, char *from, char *to,
   
   /* write status log */
   mkdir(SPOOL"/LOG",S_IRUSR|S_IWUSR|S_IXUSR);
-  snprintf(MAXS(tmp),SPOOL"/LOG/%s:%s",from,host);
+  snprintf(tmp,sizeof(tmp)-1,SPOOL"/LOG/%s:%s",from,host);
   if ((mailf=rfopen(tmp,"a"))) {
     chmod(tmp,S_IRUSR|S_IWUSR);
-    snprintf(MAXS(tmp),"'%s' to %s",fname,to);
+    snprintf(tmp,sizeof(tmp)-1,"'%s' to %s",fname,to);
     utf2iso(1,line,NULL,NULL,tmp);
     timetick=time(0);
     strftime(tmp,21,DATEFORMAT,localtime(&timetick));
@@ -3375,14 +3375,14 @@ int saftserver_connect(char *host, char *error) {
   for (hopcount=1; hopcount<11; hopcount++) {
      
     /* tell where to send to */
-    snprintf(MAXS(tmp),"opening connection to %s:%d",host,port);
+    snprintf(tmp,sizeof(tmp)-1,"opening connection to %s:%d",host,port);
     dbgout(tmp);
 
     /* initiate the connection to the server */
     sockfd=open_connection(host,port);
     if (sockfd==-3 && port==SAFT) {
-      snprintf(MAXS(server),"saft.%s",host); 
-      snprintf(MAXS(tmp),"opening connection to %s:%d",server,SAFT);
+      snprintf(server,sizeof(server)-1,"saft.%s",host); 
+      snprintf(tmp,sizeof(tmp)-1,"opening connection to %s:%d",server,SAFT);
       dbgout(tmp);
       sockfd=open_connection(server,SAFT);
       switch (sockfd) {
@@ -3419,7 +3419,7 @@ int saftserver_connect(char *host, char *error) {
     status=check_forward(sockfd,tmp,host,error);
     if (status==-1) return(-1);
     if (status==1) {
-      snprintf(MAXS(tmp),"forward points to %s",host);
+      snprintf(tmp,sizeof(tmp)-1,"forward points to %s",host);
       dbgout(tmp);
       colon=NULL;
       port=487;
@@ -3427,7 +3427,7 @@ int saftserver_connect(char *host, char *error) {
     }
 
     /* connection is successfull */
-    snprintf(MAXS(tmp),"connected to %s:%d",host,port);
+    snprintf(tmp,sizeof(tmp)-1,"connected to %s:%d",host,port);
     *error=0;
     dbgout(tmp);
     return(sockfd);
@@ -3477,14 +3477,14 @@ int saftserver_connect(char *host, char *error) {
   for (hopcount=1; hopcount<11; hopcount++) {
      
     /* tell where to send to */
-    snprintf(MAXS(tmp),"opening connection to %s:%s",host,service);
+    snprintf(tmp,sizeof(tmp)-1,"opening connection to %s:%s",host,service);
     dbgout(tmp);
 
     /* initiate the connection to the server */
     sockfd=open_connection(host,service);
     if (sockfd==-3 && (strcasecmp(service, SERVICE) == 0 || strcmp(service, PORT_STRING) == 0)) {
-      snprintf(MAXS(server),"saft.%s",host); 
-      snprintf(MAXS(tmp),"opening connection to %s:%s",server,SERVICE);
+      snprintf(server,sizeof(server)-1,"saft.%s",host); 
+      snprintf(tmp,sizeof(tmp)-1,"opening connection to %s:%s",server,SERVICE);
       dbgout(tmp);
       sockfd=open_connection(server,SERVICE);
       switch (sockfd) {
@@ -3523,7 +3523,7 @@ int saftserver_connect(char *host, char *error) {
     status=check_forward(sockfd,tmp,host,error);
     if (status==-1) return(-1);
     if (status==1) {
-      snprintf(MAXS(tmp),"forward points to %s",host);
+      snprintf(tmp,sizeof(tmp)-1,"forward points to %s",host);
       dbgout(tmp);
       colon=NULL;
       service = SERVICE;
@@ -3531,7 +3531,7 @@ int saftserver_connect(char *host, char *error) {
     }
 
     /* connection is successfull */
-    snprintf(MAXS(tmp),"connected to %s:%s",host,service);
+    snprintf(tmp,sizeof(tmp)-1,"connected to %s:%s",host,service);
     *error=0;
     dbgout(tmp);
     return(sockfd);
@@ -3576,7 +3576,7 @@ int mail_report(const char *host) {
   /* stupid NeXT has a broken readdir(); this is a dirty workaround */
 
   /* open LOG dir */
-  snprintf(MAXS(cmd),"ls *:%s 2>/dev/null",host);
+  snprintf(cmd,sizeof(cmd)-1,"ls *:%s 2>/dev/null",host);
   if ((dp=popen(cmd,"r")) == NULL) {
     exit(0);
     if (parallel) continue;
@@ -3597,7 +3597,7 @@ int mail_report(const char *host) {
   while ((dire=readdir(dp))) {
     
     strcpy(mailfn,dire->d_name);
-    snprintf(MAXS(tmp),"*:%s",host);
+    snprintf(tmp,sizeof(tmp)-1,"*:%s",host);
     if (simplematch(mailfn,tmp,0)<1) continue;
 #endif
     mailf=rfopen(mailfn,"r");
@@ -3693,7 +3693,7 @@ void check_outspool(int bounce) {
   while ((dire=readdir(dp))) {
    
     /* ignore non-header files */
-    snprintf(MAXS(oshfn),"%s",dire->d_name);
+    snprintf(oshfn,sizeof(oshfn)-1,"%s",dire->d_name);
     if (!str_eq(&oshfn[strlen(oshfn)-2],".h")) continue;
 #endif
 
@@ -3703,7 +3703,7 @@ void check_outspool(int bounce) {
 
     /* spool time expired? */
     if (timetick>finfo.st_mtime+bounce*DAYSEC) {
-      snprintf(MAXS(tmp),"no connection within %d days",bounce);
+      snprintf(tmp,sizeof(tmp)-1,"no connection within %d days",bounce);
       bounce_file(oshfn,tmp);
     }
   }
@@ -3749,8 +3749,8 @@ int bounce_file(char *file, char *comment) {
     cp++;
   else
     cp=file;
-  snprintf(MAXS(oshfn),OUTGOING"/%s",cp);
-  snprintf(MAXS(osdfn),OUTGOING"/%s",cp);
+  snprintf(oshfn,sizeof(oshfn)-1,OUTGOING"/%s",cp);
+  snprintf(osdfn,sizeof(osdfn)-1,OUTGOING"/%s",cp);
   osdfn[strlen(osdfn)-1]='d';
   
   if (stat(oshfn,&finfo)<0) return(-1);
@@ -3758,7 +3758,7 @@ int bounce_file(char *file, char *comment) {
 
   /* get user name and spool directory */
   if (!(pwe=getpwuid(finfo.st_uid))) return(-1);
-  snprintf(MAXS(userspool),SPOOL"/%s",pwe->pw_name);
+  snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",pwe->pw_name);
 
   /* create user spool directory if necessary */
   if (mkdir(userspool,S_IRUSR|S_IWUSR|S_IXUSR)==0)
@@ -3788,8 +3788,8 @@ int bounce_file(char *file, char *comment) {
   }
 
   /* set file names */
-  snprintf(MAXS(shfn),"%d.h",id);
-  snprintf(MAXS(sdfn),"%d.d",id);
+  snprintf(shfn,sizeof(shfn)-1,"%d.h",id);
+  snprintf(sdfn,sizeof(sdfn)-1,"%d.d",id);
 
   if (!(outf=rfopen(shfn,"w"))) {
     fclose(inf);
@@ -3814,7 +3814,7 @@ int bounce_file(char *file, char *comment) {
 
     /* add new bounce COMMENT */
     if (str_eq(hline,"TO")) {
-      snprintf(MAXS(tmp),"cannot sent to %s : %s",arg,comment);
+      snprintf(tmp,sizeof(tmp)-1,"cannot sent to %s : %s",arg,comment);
       iso2utf(arg,tmp);
       fprintf(outf,"COMMENT\t%s\n",arg);
       continue;
@@ -3930,7 +3930,7 @@ int check_userspool(char *user, int userconfighome) {
   pwe=NULL;
 #ifdef NEXT
   /* stupid NeXT has a broken getpwnam(); this is a dirty workaround */
-  snprintf(MAXS(tmp),"( nidump passwd . ; nidump passwd / ) | "
+  snprintf(tmp,sizeof(tmp)-1,"( nidump passwd . ; nidump passwd / ) | "
               "awk -F: '$1==\"%s\"{print $3,$4;exit}'",user);
   pp=popen(tmp,"r");
   if (fgetl(tmp,pp) && *tmp!='\n' && *tmp!=0) {
@@ -3958,8 +3958,8 @@ int check_userspool(char *user, int userconfighome) {
 
   /* build user spool string */
   user[32]=0;
-  snprintf(MAXS(userspool),SPOOL"/%s",user);
-  snprintf(MAXS(userconfig),"%s/config",userspool);
+  snprintf(userspool,sizeof(userspool)-1,SPOOL"/%s",user);
+  snprintf(userconfig,sizeof(userconfig)-1,"%s/config",userspool);
 
   /* create user spool directory for user */
   if (mkdir(userspool,S_IRUSR|S_IWUSR|S_IXUSR)==0) chown(userspool,ruid,rgid);
@@ -4173,14 +4173,16 @@ void cleanup() {
  * RETURN: nothing, but terminates program on error
  */
 void setreugid() {
-  if (rgid && setegid(rgid)<0) {
-    printf("490 Internal error on setegid(%u): %s\r\n",
-	   (unsigned int)rgid,strerror(errno));
+  if (rgid && rgid != getegid() && setegid(rgid)<0) {
+    printf("490 Internal error on setegid(%u): %s [%u/%u]\r\n",
+	   (unsigned int)rgid,strerror(errno),
+	   geteuid(), getegid());
     exit(1);
   }
-  if (ruid && seteuid(ruid)<0) {
-    printf("490 Internal error on seteuid(%u): %s\r\n",
-	   (unsigned int)ruid,strerror(errno));
+  if (ruid && ruid != geteuid() && seteuid(ruid)<0) {
+    printf("490 Internal error on seteuid(%u): %s [%u/%u]\r\n",
+	   (unsigned int)ruid,strerror(errno),
+	   geteuid(), getegid());
     exit(1);
   }
 }
@@ -4222,13 +4224,13 @@ int sudo(const char *user, const char *cmd) {
   if (setuid(pwe->pw_uid)<0) exit(1);
 
   /* set some usefull environment variables */
-  snprintf(MAXS(tmp),"HOME=%s",pwe->pw_dir);
+  snprintf(tmp,sizeof(tmp)-1,"HOME=%s",pwe->pw_dir);
   putenv(tmp);
-  snprintf(MAXS(tmp),"SHELL=%s",pwe->pw_shell);
+  snprintf(tmp,sizeof(tmp)-1,"SHELL=%s",pwe->pw_shell);
   putenv(tmp);
-  snprintf(MAXS(tmp),"USER=%s",user);
+  snprintf(tmp,sizeof(tmp)-1,"USER=%s",user);
   putenv(tmp);
-  snprintf(MAXS(tmp),"LOGNAME=%s",user);
+  snprintf(tmp,sizeof(tmp)-1,"LOGNAME=%s",user);
   putenv(tmp);
   putenv("TERM=");
   
diff --git a/src/sendmsg.c b/src/sendmsg.c
index 23c60b1..2dd4318 100644
--- a/src/sendmsg.c
+++ b/src/sendmsg.c
@@ -260,10 +260,10 @@ int main(int argc, char *argv[]) {
     else {
    
       /* test if you can receive messages */
-      snprintf(MAXS(line),"FROM %s",login);
+      snprintf(line,sizeof(line)-1,"FROM %s",login);
       sock_putline(sockfd,line);
       sock_getline(sockfd,line);
-      snprintf(MAXS(line),"TO %s",login);
+      snprintf(line,sizeof(line)-1,"TO %s",login);
       sock_putline(sockfd,line);
       sock_getline(sockfd,line);
       if (str_beq(line,"521 ")) {
@@ -281,7 +281,7 @@ int main(int argc, char *argv[]) {
         else {
 
 	  /* the message tty config file */
-	  snprintf(MAXS(msgcf),"%s/%s/config/tty@%s",SPOOL,login,localhost);
+	  snprintf(msgcf,sizeof(msgcf)-1,"%s/%s/config/tty@%s",SPOOL,login,localhost);
 
 	  /* open tty write permissions if necessary */
 	  if (receive) {
@@ -293,14 +293,14 @@ int main(int argc, char *argv[]) {
 		fprintf(outf,"%s\n",tty);
 		fclose(outf);
 		if (chmod(tty,S_IRUSR|S_IWUSR|S_IWGRP)<0) {
-		  snprintf(MAXS(tmp),"cannot open your tty %s for writing",tty);
+		  snprintf(tmp,sizeof(tmp)-1,"cannot open your tty %s for writing",tty);
 		  message(prg,'W',tmp);
 		} else if (argc-optind<1) {
 		  message(prg,'I',
 			  "receiving messages is now restricted to this tty");
 		}
 	      } else {
-		snprintf(MAXS(tmp),"cannot configure your tty "
+		snprintf(tmp,sizeof(tmp)-1,"cannot configure your tty "
 			 "(no write access to %s)",msgcf);
 		message(prg,'W',tmp);
 	      }
@@ -318,7 +318,7 @@ int main(int argc, char *argv[]) {
 	    /* is the current tty writable? */
 	    if (stat(tty,&finfo)<0 || !(finfo.st_mode&S_IWGRP)) {
 	      errno=0;
-	      snprintf(MAXS(tmp),"your tty %s is write protected; "
+	      snprintf(tmp,sizeof(tmp)-1,"your tty %s is write protected; "
 		       "try sendmsg -m",tty);
 	      message(prg,'F',tmp);
 	    }
@@ -401,7 +401,7 @@ int main(int argc, char *argv[]) {
       }
 
       /* send the message */
-      snprintf(MAXS(tmp),"MSG %s",utf_msg);
+      snprintf(tmp,sizeof(tmp)-1,"MSG %s",utf_msg);
       sendheader(sockfd,tmp);
       
     }
@@ -433,7 +433,7 @@ int main(int argc, char *argv[]) {
       iso2utf(utf_msg,iso_msg);
 
       /* send the message */
-      snprintf(MAXS(line),"MSG %s",utf_msg);
+      snprintf(line,sizeof(line)-1,"MSG %s",utf_msg);
       sock_putline(sockfd,line);
       xonf=0;
       sr=getreply(sockfd);
@@ -441,12 +441,12 @@ int main(int argc, char *argv[]) {
      
       if (!(str_beq(sr,"200") || str_beq(sr,"202"))) {
         if (strstr(sr,"Timeout")) {
-          snprintf(MAXS(tmp),"server timeout");
+          snprintf(tmp,sizeof(tmp)-1,"server timeout");
           message(prg,'W',tmp);
           sockfd=saft_connect("msg",recipient,user,host,tmp);
           sendheader(sockfd,line);
         } else {
-          snprintf(MAXS(tmp),"server error: %s",sr+4);
+          snprintf(tmp,sizeof(tmp)-1,"server error: %s",sr+4);
           message(prg,'X',tmp);
         }
       }
diff --git a/src/spool.c b/src/spool.c
index a1fdd8e..5f36085 100644
--- a/src/spool.c
+++ b/src/spool.c
@@ -181,7 +181,7 @@ struct senderlist *scanspool(char *sender) {
   /* mega stupid NeXT has broken readdir() */
 #ifdef NEXT
   /* open spool dir */
-  snprintf(MAXS(tmp),"ls %s 2>/dev/null",userspool);
+  snprintf(tmp,sizeof(tmp)-1,"ls %s 2>/dev/null",userspool);
   if ((pp=popen(tmp,"r")) == NULL) return(NULL);
 
   /* scan through spool directory */
@@ -216,7 +216,7 @@ struct senderlist *scanspool(char *sender) {
 #endif
 
       /* open header file */
-      snprintf(MAXS(file),"%s/%d.h",userspool,id);
+      snprintf(file,sizeof(file)-1,"%s/%d.h",userspool,id);
       hf=rfopen(file,"r");
       
       /* error? */
@@ -224,7 +224,7 @@ struct senderlist *scanspool(char *sender) {
        
 	/* called from receive client? */
 	if (client) {
-	  snprintf(MAXS(msg),"cannot open spool file %s",file);
+	  snprintf(msg,sizeof(msg)-1,"cannot open spool file %s",file);
 	  message("",'E',msg);
 	}
 
@@ -246,9 +246,9 @@ struct senderlist *scanspool(char *sender) {
       compress="";
 
       /* does the spool data file exist? */
-      snprintf(MAXS(file),"%s/%d.d",userspool,id);
+      snprintf(file,sizeof(file)-1,"%s/%d.d",userspool,id);
       if (stat(file,&finfo)<0) {
-	snprintf(MAXS(file),"%s/%d.h",userspool,id);
+	snprintf(file,sizeof(file)-1,"%s/%d.h",userspool,id);
 	unlink(file);
 	continue;
       }
@@ -260,7 +260,7 @@ struct senderlist *scanspool(char *sender) {
       if (keep>0 && (ctime-rtime)/DAYSEC>=keep) {
         fclose(hf);
 	unlink(file);
-	snprintf(MAXS(file),"%s/%d.h",userspool,id);
+	snprintf(file,sizeof(file)-1,"%s/%d.h",userspool,id);
 	unlink(file);
 	continue;
       }
@@ -293,7 +293,7 @@ struct senderlist *scanspool(char *sender) {
         if (str_eq(hline,"FROM")) {
 	  if ((cp=strchr(arg,' '))) {
 	    *cp=0;
-	    snprintf(MAXS(tmp),"%s (%s)",arg,cp+1);
+	    snprintf(tmp,sizeof(tmp)-1,"%s (%s)",arg,cp+1);
 	  } else
 	    strcpy(tmp,arg);
 	  utf2iso(0,from,NULL,NULL,tmp);
@@ -372,9 +372,9 @@ struct senderlist *scanspool(char *sender) {
       /* junk file expired? */
       if (*from==0 || *fname==0 || 
 	  (tsize!=csize && deljunk>0 && (ctime-rtime)/DAYSEC>=deljunk)) {
-        snprintf(MAXS(file),"%s/%d.d",userspool,id);
+        snprintf(file,sizeof(file)-1,"%s/%d.d",userspool,id);
 	unlink(file);
-	snprintf(MAXS(file),"%s/%d.h",userspool,id);
+	snprintf(file,sizeof(file)-1,"%s/%d.h",userspool,id);
 	unlink(file);
 	continue;
       }
@@ -539,7 +539,7 @@ struct hostlist *scanoutspool(char *sender) {
   /* mega stupid NeXT has broken readdir() */
 #ifdef NEXT
   /* open spool dir */
-  snprintf(MAXS(tmp),"cd %s;ls %s_*.h 2>/dev/null",OUTGOING,sender);
+  snprintf(tmp,sizeof(tmp)-1,"cd %s;ls %s_*.h 2>/dev/null",OUTGOING,sender);
   if ((pp=popen(tmp,"r")) == NULL) return(NULL);
 
   /* scan through spool directory */
@@ -561,18 +561,18 @@ struct hostlist *scanoutspool(char *sender) {
 #endif
 
     /* look for header files */
-    snprintf(MAXS(tmp),"%s*.h",sender);
+    snprintf(tmp,sizeof(tmp)-1,"%s*.h",sender);
     if (simplematch(hfn,tmp,1)==0) continue;
 
     strcpy(tmp,hfn);
-    snprintf(MAXS(hfn),OUTGOING"/%s",tmp);
+    snprintf(hfn,sizeof(hfn)-1,OUTGOING"/%s",tmp);
 
     /* open header file */
     if ((hf=rfopen(hfn,"r")) == NULL) {
      
       /* called from receive client? */
       if (client) {
-        snprintf(MAXS(msg),"cannot open outgoing spool file %s",hfn);
+        snprintf(msg,sizeof(msg)-1,"cannot open outgoing spool file %s",hfn);
 	message("",'E',msg);
       }
 
@@ -776,19 +776,19 @@ int delete_sf(struct filelist *flp, int verbose) {
   extern int client;		/* flag to determine client or server */
   extern char userspool[];	/* user spool directory */
 
-  snprintf(MAXS(file),"%s/%d.d",userspool,flp->id);
+  snprintf(file,sizeof(file)-1,"%s/%d.d",userspool,flp->id);
   unlink(file);
-  snprintf(MAXS(file),"%s/%d.h",userspool,flp->id);
+  snprintf(file,sizeof(file)-1,"%s/%d.h",userspool,flp->id);
   utf2iso(1,NULL,fname,NULL,flp->fname);
   if(unlink(file)<0) {
     if (client) {
-      snprintf(MAXS(msg),"cannot delete spoolfile #%d",flp->id);
+      snprintf(msg,sizeof(msg)-1,"cannot delete spoolfile #%d",flp->id);
       message("",'W',msg);
     }
     return(-1);
   } else {
     if (verbose) {
-      snprintf(MAXS(msg),"%s deleted",fname);
+      snprintf(msg,sizeof(msg)-1,"%s deleted",fname);
       message("",'I',msg);
     }
     return(0);
@@ -874,7 +874,7 @@ int spoolid(int maxfiles) {
     if (n>maxfiles) return(-n);
 
     /* try to create header spool file */
-    snprintf(MAXS(file),"%d.h",id);
+    snprintf(file,sizeof(file)-1,"%d.h",id);
     fd=open(file,O_CREAT|O_EXCL,S_IRUSR|S_IWUSR);
 
     /* successfull? */
@@ -883,7 +883,7 @@ int spoolid(int maxfiles) {
       close(fd);
 
       /* create data spool file */
-      snprintf(MAXS(file),"%d.d",id);
+      snprintf(file,sizeof(file)-1,"%d.d",id);
       close(open(file,O_CREAT|O_LARGEFILE,S_IRUSR|S_IWUSR));
 
       return(id);
