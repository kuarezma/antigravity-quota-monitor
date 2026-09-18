#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Antigravity Canlı Model Kota & Limit Takipçisi (Starware)
#  GitHub: https://github.com/kuarezma/antigravity-quota-monitor
# ==============================================================================
# Kurulum (Tek Komut):
#   curl -fsSL https://raw.githubusercontent.com/kuarezma/antigravity-quota-monitor/main/install.sh | bash
#
# Kaldırma:
#   bash install.sh --uninstall
# ==============================================================================

set -e

REPO_OWNER="kuarezma"
REPO_NAME="antigravity-quota-monitor"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
RAW_BASE="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main"

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
GRAY='\033[0;90m'
NC='\033[0m'

OS_TYPE="$(uname -s)"
INSTALL_DIR="$HOME/.local/bin"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.antigravity.hud.plist"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/antigravity-hud.service"
PLUGIN_DIR="$HOME/.gemini/config/plugins/antigravity-quota-monitor"

# ------------------------------------------------------------------------------
# 1. KALDIRMA (--uninstall)
# ------------------------------------------------------------------------------
if [ "$1" == "--uninstall" ] || [ "$1" == "-u" ]; then
    echo -e "${YELLOW}⚡ Antigravity Kota Takipçisi sistemden kaldırılıyor...${NC}"

    # macOS LaunchAgent temizliği
    if [ "$OS_TYPE" == "Darwin" ] && [ -f "$PLIST_FILE" ]; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        rm -f "$PLIST_FILE"
        echo -e "${GREEN}✓ LaunchAgent servisi durduruldu ve silindi.${NC}"
    fi

    # Linux systemd temizliği
    if [ "$OS_TYPE" == "Linux" ] && [ -f "$SERVICE_FILE" ]; then
        systemctl --user stop antigravity-hud.service 2>/dev/null || true
        systemctl --user disable antigravity-hud.service 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        systemctl --user daemon-reload 2>/dev/null || true
        echo -e "${GREEN}✓ Linux systemd servisi durduruldu ve silindi.${NC}"
    fi

    rm -f "$INSTALL_DIR/agy-quota"
    rm -f "$INSTALL_DIR/agy-hud-daemon"
    echo -e "${GREEN}✓ Komut dosyaları ($INSTALL_DIR) temizlendi.${NC}"

    rm -rf "$PLUGIN_DIR"
    echo -e "${GREEN}✓ Antigravity eklentisi silindi.${NC}"

    echo -e "${GREEN}✓ Kaldırma tamamlandı. Antigravity uygulamasını yeniden başlatabilirsiniz.${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. KARŞILAMA VE STARWARE ŞARTI ⭐
# ------------------------------------------------------------------------------
clear 2>/dev/null || true
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     ⚡ Antigravity Canlı Kota ve Limit Takipçisi Kurulum Aracı       ║${NC}"
echo -e "${CYAN}║        https://github.com/$REPO_OWNER/$REPO_NAME         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${PURPLE}⭐ [STARWARE LİSANSI] ⭐${NC}"
echo -e "Bu yazılım tamamen ücretsiz ve açık kaynaklıdır."
echo -e "Yazılımı kullanmanın tek kuralı: ${YELLOW}GitHub reposunu yıldızlayarak (Star ⭐) projeye destek olmaktır!${NC}"
echo ""

# Yıldız kontrolü / isteği
STARRED=false

if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    if gh api "user/starred/$REPO_OWNER/$REPO_NAME" --silent 2>/dev/null; then
        STARRED=true
        echo -e "${GREEN}🎉 Repoyu daha önce yıldızladığınız tespit edildi! Desteğiniz için teşekkürler!${NC}"
    else
        echo -e "${YELLOW}👉 GitHub CLI (gh) tespit edildi. Repoyu sizin adınıza yıldızlayalım mı? [E/h]:${NC} "
        read -r STAR_CHOICE </dev/tty || STAR_CHOICE="e"
        if [[ "$STAR_CHOICE" =~ ^[eEyY] ]] || [[ -z "$STAR_CHOICE" ]]; then
            if gh api -X PUT "user/starred/$REPO_OWNER/$REPO_NAME" --silent 2>/dev/null; then
                echo -e "${GREEN}⭐ Harika! Repo başarıyla yıldızlandı.${NC}"
                STARRED=true
            fi
        fi
    fi
fi

if [ "$STARRED" = false ]; then
    echo -e "${CYAN}👉 Lütfen repoyu açıp sağ üstteki ⭐ Star butonuna basın:${NC}"
    echo -e "${YELLOW}   $REPO_URL ${NC}"
    echo ""
    if command -v open &> /dev/null; then
        open "$REPO_URL" 2>/dev/null || true
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$REPO_URL" 2>/dev/null || true
    fi
    echo -e "${GRAY}Yıldızladıktan sonra kuruluma devam etmek için ENTER tuşuna basın...${NC}"
    read -r </dev/tty || true
    echo -e "${GREEN}⭐ Desteğiniz için çok teşekkürler! Kuruluma geçiliyor...${NC}\n"
fi

# ------------------------------------------------------------------------------
# 3. SİSTEM VE PYTHON KONTROLÜ
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Python ortamı ve bağımlılıklar kontrol ediliyor...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Hata: Sisteminizde Python 3 bulunamadı. Lütfen Python 3 kurun.${NC}"
    exit 1
fi

if ! python3 -c "import websockets" &> /dev/null; then
    echo -e "${GRAY}↳ 'websockets' kütüphanesi kuruluyor...${NC}"
    python3 -m pip install --quiet --user websockets || pip3 install --quiet websockets
fi
echo -e "${GREEN}✓ Python 3 ve 'websockets' hazır.${NC}"

# ------------------------------------------------------------------------------
# 4. KOMUT DOSYALARININ YERLEŞTİRİLMESİ (Single Source of Truth)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/4] Komut dosyaları kuruluyor ($INSTALL_DIR)...${NC}"
mkdir -p "$INSTALL_DIR"

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/agy-quota" ] && [ -f "$SCRIPT_DIR/bin/agy-hud-daemon" ]; then
    echo -e "${GRAY}↳ Yerel depo dosyalarından kopyalanıyor...${NC}"
    cp -f "$SCRIPT_DIR/bin/agy-quota" "$INSTALL_DIR/agy-quota"
    cp -f "$SCRIPT_DIR/bin/agy-hud-daemon" "$INSTALL_DIR/agy-hud-daemon"
else
    echo -e "${GRAY}↳ GitHub deposundan en güncel dosyalar indiriliyor...${NC}"
    curl -fsSL "$RAW_BASE/bin/agy-quota" -o "$INSTALL_DIR/agy-quota"
    curl -fsSL "$RAW_BASE/bin/agy-hud-daemon" -o "$INSTALL_DIR/agy-hud-daemon"
fi

chmod +x "$INSTALL_DIR/agy-quota"
chmod +x "$INSTALL_DIR/agy-hud-daemon"
echo -e "${GREEN}✓ 'agy-quota' ve 'agy-hud-daemon' başarıyla kuruldu.${NC}"

# PATH Kontrolü
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${GRAY}↳ ~/.local/bin PATH değişkenine ekleniyor...${NC}"
    if [ -f "$HOME/.zshrc" ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
fi

# ------------------------------------------------------------------------------
# 5. ARKA PLAN SERVİSİ (macOS LaunchAgent veya Linux systemd)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/4] Arka plan servisi yapılandırılıyor ($OS_TYPE)...${NC}"
PYTHON_BIN="$(command -v python3)"

if [ "$OS_TYPE" == "Darwin" ]; then
    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat << EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.antigravity.hud</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_BIN</string>
        <string>$INSTALL_DIR/agy-hud-daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/agy-hud.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/agy-hud.err</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    echo -e "${GREEN}✓ macOS 'com.antigravity.hud' LaunchAgent servisi başlatıldı.${NC}"

elif [ "$OS_TYPE" == "Linux" ]; then
    mkdir -p "$SYSTEMD_USER_DIR"
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Antigravity Responsive Quota HUD Daemon
After=network.target

[Service]
ExecStart=$PYTHON_BIN $INSTALL_DIR/agy-hud-daemon
Restart=always
RestartSec=5
StandardOutput=file:/tmp/agy-hud.log
StandardError=file:/tmp/agy-hud.err

[Install]
WantedBy=default.target
EOF
    if command -v systemctl &> /dev/null; then
        systemctl --user daemon-reload
        systemctl --user enable --now antigravity-hud.service 2>/dev/null || true
        echo -e "${GREEN}✓ Linux systemd 'antigravity-hud.service' servisi başlatıldı.${NC}"
    else
        echo -e "${YELLOW}⚠️ Uyarı: systemctl bulunamadı. Servisi manuel başlatabilirsiniz: $INSTALL_DIR/agy-hud-daemon &${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Bilinmeyen işletim sistemi ($OS_TYPE). Arka plan servisi manuel başlatılabilir: $INSTALL_DIR/agy-hud-daemon &${NC}"
fi

# ------------------------------------------------------------------------------
# 6. ANTIGRAVITY ASİSTAN EKLENTİSİ (/quota)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/4] Antigravity '/quota' slash komutu entegre ediliyor...${NC}"
mkdir -p "$PLUGIN_DIR/skills/quota-monitor"

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/plugin" ]; then
    cp -R "$SCRIPT_DIR/plugin/"* "$PLUGIN_DIR/"
else
    curl -fsSL "$RAW_BASE/plugin/plugin.json" -o "$PLUGIN_DIR/plugin.json"
    curl -fsSL "$RAW_BASE/plugin/skills/quota-monitor/SKILL.md" -o "$PLUGIN_DIR/skills/quota-monitor/SKILL.md"
fi
echo -e "${GREEN}✓ Antigravity eklentisi başarıyla entegre edildi.${NC}"

echo -e "\n${GREEN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 TEBRİKLER! Kurulum başarıyla tamamlandı.${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "Şimdi neler yapabilirsiniz:"
echo -e " 1. ${CYAN}Sohbet Ekranı:${NC} Antigravity penceresine geçin; yazma kutusunun üstünde canlı bar görünecektir."
echo -e " 2. ${CYAN}Zengin Hover Kartı:${NC} Barın üzerine gelerek tüm model havuzlarının ayrıntılarını görün."
echo -e " 3. ${CYAN}Terminalden Takip:${NC} Terminalde ${YELLOW}agy-quota${NC} yazarak renkli kota grafiğini görün."
echo -e " 4. ${CYAN}Sohbet İçinde:${NC} Sohbet kutusuna ${YELLOW}/quota${NC} yazarak limitlerinizi asistana sorabilirsiniz."
echo ""
