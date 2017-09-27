require 'formula'

class AsipStatus < Formula
  url 'https://raw.github.com/Netatalk/Netatalk/master/contrib/shell_utils/asip-status.pl.in'
  homepage 'http://netatalk.sourceforge.net/'
  sha256 'c4b5129f0a99a25937065d1668068c1c736d08535e4fc60ff9e748b79249b2e9'
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
