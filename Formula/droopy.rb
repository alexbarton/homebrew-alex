class Droopy < Formula
  desc "Mini web server that let others upload files to your computer"
  homepage "https://github.com/stackp/Droopy"
  url "https://github.com/stackp/Droopy.git", :revision => "7a9c7bc46c4ff8b743755be86a9b29bd1a8ba1d9"
  version "20160830"

  depends_on "python"

  def install
    bin.install "droopy"
    man1.install "man/droopy.1"
  end

  test do
    system "#{bin}/droopy", "--help"
  end
end
