class Droopy < Formula
  desc "Mini web server that let others upload files to your computer"
  homepage "https://github.com/stackp/Droopy"
  url "https://github.com/stackp/Droopy.git", :revision => "b7b0bb9d003aed019bc5303e854089cd3e44f64c"
  version "20131121"

  depends_on :python if MacOS.version <= :snow_leopard

  def install
    bin.install "droopy"
    man1.install "man/droopy.1"
  end

  test do
    system "#{bin}/droopy", "--help"
  end
end
