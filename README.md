<p align="center">
  <img src="assets/quota-bar-preview.png" alt="Antigravity Quota HUD" width="820" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.5);" />
</p>

<h1 align="center">⚡ Antigravity Canlı Model Kota & Limit Takipçisi</h1>

<p align="center">
  <b>Antigravity</b> masaüstü uygulamasının sohbet penceresi içine yerleşen; <b>Gemini</b>, <b>Claude</b> ve <b>GPT</b> limitlerini saniye saniye canlı geri sayımla ve doğal koyu temayla gösteren açık kaynaklı eklenti.
</p>

<p align="center">
  <a href="https://github.com/kuarezma/antigravity-quota-monitor/stargazers"><img src="https://img.shields.io/github/stars/kuarezma/antigravity-quota-monitor?style=for-the-badge&color=f59e0b&label=Stars%20%E2%AD%90" alt="Stars" /></a>
  <a href="https://github.com/kuarezma/antigravity-quota-monitor/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/kuarezma/antigravity-quota-monitor/ci.yml?branch=main&style=for-the-badge&label=CI%20Tests" alt="CI Status" /></a>
  <a href="https://github.com/kuarezma/antigravity-quota-monitor/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT%20%28Starware%29-38bdf8?style=for-the-badge" alt="License" /></a>
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-10b981?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/Antigravity-v2.x-8b5cf6?style=for-the-badge" alt="Antigravity Version" />
</p>

---

## 🌟 Özellikler

- ⏱️ **Canlı Saniye Saniye Geri Sayım:** Limitlerin tam olarak sıfırlanacağı zamana kalan süreyi dinamik olarak geri sayar.
- 🎨 **Doğal Koyu Tema Uyumlu:** Antigravity'nin yerel sohbet kartı tasarımıyla (`rgba(24, 24, 27, 0.88)`) pürüzsüzce bütünleşir; göz yormayan, zarif bir kenarlığa sahiptir.
- 💬 **Zengin Popover Hover Kartı:** Sohbetin üstündeki kapsülün üzerine fareyle gelindiğinde tüm model havuzlarının (Gemini Flash/Pro, Claude 3.5 Sonnet, Opus, GPT-OSS) ayrıntılı yüzdelerini, ilerleme çubuklarını ve sayaçlarını gösteren şık bir detay penceresi açılır.
- 🔔 **Akıllı Masaüstü Bildirimleri (Alerter):** Kota kritik seviyeye indiğinde (%15 ve %5) veya kota sıfırlandığında yerel sistem bildirimi (macOS bildirim & ses, Linux `notify-send`) gönderir.
- 🔥 **Tüketim Hızı ve Tükenme Tahmini (Burn-Rate):** Zaman serisi analizi ile *"Bu hızla kotanız ~38 dakika içinde tükenecektir"* şeklinde akıllı tahmin sunar (`agy-quota --burn-rate`).
- 🍏 **macOS Menü Çubuğu (Menubar Status Bar):** Antigravity simge durumundayken dahi menü çubuğunda anlık kota ve geri sayımı gösteren yerel Swift menubar aracı (`agy-menubar --daemon`).
- 🌐 **Çoklu Dil Desteği (i18n):** Türkçe ve İngilizce arayüz desteği (`agy-quota --lang en` / `--lang tr`).
- 🔄 **Tam Otomatik Senkronizasyon (`● Canlı`):** Her 10 saniyede bir ve pencereye her odaklanıldığında limitleri arka planda sessizce günceller.
- 🛡️ **Akıllı Kaynak Tasarrufu (Backoff):** Antigravity kapalıyken döngü süresini kademelendirir; sıfır CPU ve pil tüketimi sağlar.
- 💻 **Güçlü Terminal Arayüzü (`agy-quota`):** Renkli ANSI ilerleme barları ve betikler için `--json` desteği.
- 💬 **Sohbet İçi Asistan Becerisi (`/quota`):** Antigravity içinde asistana doğrudan `/quota` yazarak limitlerinizi sorabilirsiniz.
- 🚀 **Otomatik Arka Plan Servisi (LaunchAgent & systemd):** macOS için `LaunchAgent`, Linux için `systemd --user` ile tek tık kurulum.
- 🍺 **Homebrew Formülü:** `Formula/antigravity-quota-monitor.rb` ile paket yöneticisi uyumluluğu.
- 🧪 **Uçtan Uca Test Edilmiş:** Kapsamlı `pytest` paketi ve GitHub Actions CI ile tam güvence.

---

## 📸 Ekran Görüntüleri

### 1. Sohbet Ekranı Görünümü (Doğal Entegrasyon)
<p align="center">
  <img src="assets/chat-preview.png" alt="Antigravity Chat Window" width="850" style="border-radius: 12px; border: 1px solid rgba(255,255,255,0.1);" />
</p>

### 2. Terminal Görünümü (`agy-quota --burn-rate`)
```
╔══════════════════════════════════════════════════════════════════════════╗
║                  ⚡ ANTIGRAVITY ANLIK KOTA VE LİMİT TAKİBİ               ║
║                  Kaynak: Yerel LanguageServer                            ║
╚══════════════════════════════════════════════════════════════════════════╝

▶ Gemini Models (Models within this group: Gemini Flash, Gemini Pro)
  • Weekly Limit Remaining       [████████████████████░░] %89.5
    ↳ ⏱️  Kalan Süre: 5 gün 20 sa 23 dk  |  Hedef: 2026-09-24T18:48:53Z
    ↳ 💤 Tüketim Yok (Beklemede)
  • Five Hour Limit Remaining    [█████████████████████░] %96.6
    ↳ ⏱️  Kalan Süre: 04:47:25 (4 sa 47 dk 25 sn)  |  Hedef: 2026-09-19T03:12:45Z
    ↳ 🔥 Tüketim Hızı: %12.4/saat | Tahmini Tükenme: ~38 dakika

▶ Claude and GPT models (Models within this group: Claude Opus, Claude Sonnet, GPT-OSS)
  • Weekly Limit Remaining       [██████████████████████] %100.0
    ↳ ⏱️  Kalan Süre: 6 gün 23 sa 58 dk  |  Hedef: 2026-09-25T22:23:29Z
  • Five Hour Limit Remaining    [██████████████████████] %100.0
    ↳ ⏱️  Kalan Süre: 04:58:09 (4 sa 58 dk 9 sn)  |  Hedef: 2026-09-19T03:23:29Z
```

---

## ⚡ Hızlı Kurulum

### Yöntem 1: Tek Komutla Kurulum (Önerilen)
```bash
curl -fsSL https://raw.githubusercontent.com/kuarezma/antigravity-quota-monitor/main/install.sh | bash
```

### Yöntem 2: Homebrew ile Kurulum
```bash
brew tap kuarezma/antigravity
brew install antigravity-quota-monitor
```

> [!IMPORTANT]
> **⭐ Starware Lisans Kuralı:**  
> Bu proje tamamen ücretsiz ve açık kaynaklıdır. Tek kullanım şartı bu repoyu **[GitHub'da Yıldızlamaktır (Star ⭐)](https://github.com/kuarezma/antigravity-quota-monitor)**.

---

## 🍏 macOS Menü Çubuğu Aracı (Menubar)

Menü çubuğundan anlık kota takibi yapmak için:

```bash
agy-menubar --daemon
```
Arka planda çalışır, en düşük kotayı ve kalan süreyi menü çubuğunda canlı gösterir.

---

## 🛠️ Mimari

```
┌─────────────────────────────────────────────────────────┐
│              Antigravity Desktop Application            │
│  ┌───────────────────────────────────────────────────┐  │
│  │   ⚡ Gemini 5s: %88 | ⏱️ 01:14:59 | Haftalık: %91  │  │ ◄─── Injected HUD Bar & Hover Popover
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Ask anything, @ to mention, / for actions...     │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────┘
                             │ Chrome DevTools Protocol (CDP)
┌────────────────────────────▼────────────────────────────┐
│         agy-hud-daemon (Arka Plan Servisi)              │
│  • DevToolsActivePort üzerinden Electron sayfasına bağlı│
│  • DOM enjeksiyonu, zengin hover kartı & uyarıcı        │
│  • Akıllı backoff ile sıfır kaynak tüketimi             │
└────────────────────────────┬────────────────────────────┘
                             │ Local HTTPS RPC
┌────────────────────────────▼────────────────────────────┐
│      Antigravity LanguageServer (Yerel Dil Motoru)      │
│  • RetrieveUserQuotaSummary Endpoint                    │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Testleri Çalıştırma

Projeyi klonladıktan sonra test paketini çalıştırabilirsiniz:

```bash
pip install websockets pytest
pytest tests/ -v
```

---

## 🗑️ Kaldırma (Uninstall)

```bash
curl -fsSL https://raw.githubusercontent.com/kuarezma/antigravity-quota-monitor/main/install.sh | bash -s -- --uninstall
```
veya yerel depodan:
```bash
bash install.sh --uninstall
```

---

## 🤝 Katkıda Bulunma & Lisans

Katkıda bulunmak için lütfen bir Issue açın veya Pull Request gönderin.

Bu proje **MIT License** ile lisanslanmıştır.  
Kullanım şartı olarak repoya **[Yıldız (Star ⭐)](https://github.com/kuarezma/antigravity-quota-monitor)** verilmesi rica olunur.
