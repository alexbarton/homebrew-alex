require 'formula'

class AsipStatus < Formula
  url 'https://raw.github.com/franklahm/Netatalk/master/contrib/shell_utils/asip-status.pl.in'
  homepage 'http://netatalk.sourceforge.net/'
  sha256 'c9e3c7687d0b250d883bfe0323bff8f4e257fc27c3c2f676688cb0c606c40086'
  version '20120724'

  def install
    system 'mv "asip-status.pl.in" "asip-status.pl"'
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
