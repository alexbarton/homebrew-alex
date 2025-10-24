require 'formula'

class AsipStatus < Formula
  url 'https://raw.githubusercontent.com/Netatalk/netatalk/refs/tags/netatalk-4-3-2/contrib/bin_utils/asip-status.pl'
  homepage 'https://netatalk.io/manual/en/asip-status.1'
  sha256 'c4ab5f6d94f93f672764247b4ce849b1c75531c82120f7621e66269d1d85d490'
  version '4.3.2'

  def install
    inreplace "asip-status.pl",
      "@PERL@", "/usr/bin/perl"
    inreplace "asip-status.pl",
      "@netatalk_version@", version
    bin.install('asip-status.pl')
  end

  def test
    system "bash", "-c", "#{bin}/asip-status.pl --version | grep -F Netatalk >/dev/null"
  end
end
