require 'formula'

class AsipStatus < Formula
  url 'https://raw.github.com/Netatalk/Netatalk/master/contrib/shell_utils/asip-status.pl.in'
  homepage 'http://netatalk.sourceforge.net/'
  sha256 '2acb0d89098b245ac130d16daca76a79fdbf6557ab58c88f6c379ceb059075a0'
  version '20211121'

  def install
    system 'mv "asip-status.pl.in" "asip-status.pl"'
    inreplace "asip-status.pl",
      "@PERL@", "/usr/bin/perl"
    inreplace "asip-status.pl",
      "@NETATALK_VERSION@", version
    bin.install('asip-status.pl')
  end

  def test
    system "bash", "-c", "#{bin}/asip-status.pl --version | grep -F Netatalk >/dev/null"
  end
end
