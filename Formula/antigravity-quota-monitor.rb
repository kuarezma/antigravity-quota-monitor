class AntigravityQuotaMonitor < Formula
  desc "Real-time AI model quota & HUD monitor for Google Antigravity"
  homepage "https://github.com/kuarezma/antigravity-quota-monitor"
  url "https://github.com/kuarezma/antigravity-quota-monitor/archive/refs/heads/main.tar.gz"
  version "1.1.0"
  license "MIT"
  head "https://github.com/kuarezma/antigravity-quota-monitor.git", branch: "main"

  depends_on "python@3.11" => :optional

  def install
    bin.install "bin/agy-quota"
    bin.install "bin/agy-hud-daemon"
    if OS.mac?
      bin.install "bin/agy-menubar"
      bin.install "bin/agy-menubar.swift"
    end
  end

  def caveats
    <<~EOS
      ⚡ Antigravity Quota Monitor kuruldu!

      Terminalden kullanım:
        agy-quota
        agy-quota --burn-rate
        agy-quota --lang en

      Arka plan HUD servisini ve eklentiyi kurmak için:
        bash <(curl -fsSL https://raw.githubusercontent.com/kuarezma/antigravity-quota-monitor/main/install.sh)
    EOS
  end

  test do
    assert_match "source", shell_output("#{bin}/agy-quota --json 2>&1 || true")
  end
end
