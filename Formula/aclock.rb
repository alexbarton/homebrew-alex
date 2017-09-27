require 'formula'

class Aclock < Formula
  url 'https://raw.githubusercontent.com/tenox7/aclock/master/sources/aclock-unix-curses.c'
  sha256 '2b098996409c4740f492fb8fd5a63cb5e3e15283c2f7e3f06c75d6a9ad916669'
  version '2.3'
  homepage 'http://www.tenox.net/out/'

  def install
    system "cc aclock-unix-curses.c -o aclock -lcurses -lm"
    bin.install 'aclock'
  end
end
