require 'formula'

class Automake111 < Formula
  homepage 'http://www.gnu.org/software/automake/'
  url 'http://ftpmirror.gnu.org/automake/automake-1.11.5.tar.gz'
  mirror 'http://ftp.gnu.org/gnu/automake/automake-1.11.5.tar.gz'
  sha1 '53949fa5b9776a5f4b6783486c037da64e374f4f'

  depends_on "autoconf" => :build

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make install"

    # remove all files that clash with the "automake" formula ...
    system "rm", "#{prefix}/bin/aclocal"
    system "rm", "#{prefix}/bin/automake"
    system "rm", "#{prefix}/share/man/man1/aclocal.1"
    system "rm", "#{prefix}/share/man/man1/automake.1"
    system "rm", "-r", "#{prefix}/share/doc"
    system "rm", "-r", "#{prefix}/share/info"
  end

  def test
    system "#{bin}/automake", "--version"
  end
end
