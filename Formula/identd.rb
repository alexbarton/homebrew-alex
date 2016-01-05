require 'formula'

class Identd < Formula
  url 'http://rc.shaunrowland.com/git/identd.git', :using => :git
  version '0.20120228'
  homepage 'http://www.shaunrowland.com/fsync/2011/05/15/identd-for-mac-os-x/'

  def patches
    # manual page: remove "manual uninstall" description
    DATA
  end

  def install
    inreplace "identd.xcodeproj/project.pbxproj",
      /CODE_SIGN_IDENTITY = \".*\"/, 'CODE_SIGN_IDENTITY=""'
    inreplace "identd/identd.8",
      /\/usr\/local/, "#{HOMEBREW_PREFIX}"
    system "xcodebuild -target identd -configuration Release"
    sbin.install('build/Release/identd')
    man8.install('identd/identd.8')
  end
end

__END__
diff --git a/identd/identd.8 b/identd/identd.8
index fdd43b0..954e9ee 100644
--- a/identd/identd.8
+++ b/identd/identd.8
@@ -32,15 +32,6 @@ if found. This is a basic implementation of an
 .Nm
 server.
 .Pp
-The
-.Nm
-utility can be uninstalled by unloading the launchd job with:
-.Bd -literal
-sudo launchctl unload /Library/LaunchDaemons/com.shaunrowland.identd.plist
-.Ed
-.Pp
-and removing all of the files in the FILES section below.
-.Pp
 If you create a /usr/local/etc/identd.user file containing a username on a
 single line, that username will be returned if no user would be found otherwise.
 This is useful if you are behind a NAT router that causes the source and
