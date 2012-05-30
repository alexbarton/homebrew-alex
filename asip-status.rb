require 'formula'

class AsipStatus < Formula
  url 'http://netatalk.git.sourceforge.net/git/gitweb.cgi?p=netatalk/netatalk;a=blob_plain;f=contrib/shell_utils/asip-status.pl.in;hb=HEAD'
  homepage 'http://netatalk.sourceforge.net/'
  md5 '78790ac4c46cb4b08ede1f8eb8907bca'
  version '20120203'

  def install
    system 'mv "asip-status.pl.in;hb=HEAD" "asip-status.pl"'
    inreplace "asip-status.pl",
      "@PERL@", "/usr/bin/perl"
    inreplace "asip-status.pl",
      " @NETATALK_VERSION@", ""
    bin.install('asip-status.pl')
  end

  def test
    system "bash", "-c", "#{bin}/asip-status.pl --version; test $? -eq 255"
  end
end
