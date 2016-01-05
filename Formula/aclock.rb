require 'formula'

class Aclock < Formula
  url 'http://www.tenox.net/out/aclock-unix-curses.c'
  sha1 '87b15f6030e27de3ac689e01120db2dd21003b3c'
  version '2.3'
  homepage 'http://www.tenox.net/out/'

  def install
    system "cc aclock-unix-curses.c -o aclock -lcurses -lm"
    bin.install 'aclock'
  end
end
