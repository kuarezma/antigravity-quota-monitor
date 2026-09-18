#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Antigravity Canlı Model Kota & Limit Takipçisi (Starware)
#  GitHub: https://github.com/kuarezma/antigravity-quota-monitor
# ==============================================================================
# Kurulum:
#   curl -fsSL https://raw.githubusercontent.com/kuarezma/antigravity-quota-monitor/main/install.sh | bash
#
# Kaldırma:
#   bash install.sh --uninstall
# ==============================================================================

set -e

REPO_OWNER="kuarezma"
REPO_NAME="antigravity-quota-monitor"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
GRAY='\033[0;90m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.antigravity.hud.plist"
PLUGIN_DIR="$HOME/.gemini/config/plugins/antigravity-quota-monitor"

# ------------------------------------------------------------------------------
# 1. KALDIRMA (--uninstall)
# ------------------------------------------------------------------------------
if [ "$1" == "--uninstall" ] || [ "$1" == "-u" ]; then
    echo -e "${YELLOW}⚡ Antigravity Kota Takipçisi sistemden kaldırılıyor...${NC}"
    
    if [ -f "$PLIST_FILE" ]; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        rm -f "$PLIST_FILE"
        echo -e "${GREEN}✓ LaunchAgent servisi durduruldu ve silindi.${NC}"
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
    # gh CLI giriş yapılmış
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
    # Tarayıcıyı açmayı dene
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
# 4. KOMUT DOSYALARININ OLUŞTURULMASI
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/4] Komut dosyaları kuruluyor ($INSTALL_DIR)...${NC}"
mkdir -p "$INSTALL_DIR"

# 4.1 agy-quota (CLI Aracı)
cat << 'EOF' > "$INSTALL_DIR/agy-quota"
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota Monitor CLI (agy-quota)
Anlık model kotası, kalan yüzdeler ve sıfırlanma süresi takipçisi.
"""

import sys
import os
import subprocess
import re
import json
import urllib.request
import ssl
from datetime import datetime, timezone

def fetch_quota_language_server():
    try:
        ps_out = subprocess.check_output(['ps', 'aux'], stderr=subprocess.DEVNULL).decode('utf-8')
        csrf_token = None
        target_pid = None
        for line in ps_out.splitlines():
            if 'language_server' in line and '--csrf_token' in line:
                m_csrf = re.search(r'--csrf_token\s+([a-f0-9\-]+)', line)
                if m_csrf:
                    csrf_token = m_csrf.group(1)
                    target_pid = line.split()[1]
                    break

        if not csrf_token or not target_pid:
            return None

        lsof_out = subprocess.check_output(['lsof', '-n', '-P', '-p', target_pid], stderr=subprocess.DEVNULL).decode('utf-8')
        ports = []
        for l in lsof_out.splitlines():
            if 'LISTEN' in l:
                p_match = re.search(r':(\d+)\s+\(LISTEN\)', l)
                if p_match:
                    ports.append(int(p_match.group(1)))

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        for port in ports:
            try:
                url = f'https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary'
                req = urllib.request.Request(url, data=b'{}', headers={
                    'Content-Type': 'application/json',
                    'X-Codeium-Csrf-Token': csrf_token
                })
                with urllib.request.urlopen(req, context=ctx, timeout=1.5) as resp:
                    data = json.loads(resp.read().decode('utf-8'))
                    return data.get('response', data)
            except Exception:
                continue
    except Exception:
        pass
    return None

def fetch_quota_cloud_api():
    try:
        token_path = os.path.expanduser('~/.gemini/jetski-standalone-oauth-token')
        with open(token_path, 'r') as f:
            tok_data = json.load(f)
        access_token = tok_data['token']['access_token']
        url = 'https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary'
        req = urllib.request.Request(url, data=b'{}', headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
            'User-Agent': 'antigravity'
        })
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception:
        pass
    return None

def get_quota():
    data = fetch_quota_language_server()
    if data:
        return data, 'Yerel LanguageServer'
    data = fetch_quota_cloud_api()
    if data:
        return data, 'Google CloudCode API'
    return None, None

def format_duration(seconds):
    if seconds <= 0:
        return "00:00:00 (Sıfırlandı)"
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    if h > 24:
        days = h // 24
        rh = h % 24
        return f"{days} gün {rh} sa {m} dk"
    return f"{h:02d}:{m:02d}:{s:02d} ({h} sa {m} dk {s} sn)"

def make_bar(fraction, width=22):
    filled = int(round(fraction * width))
    bar = "█" * filled + "░" * (width - filled)
    pct = fraction * 100
    color = "\033[92m" if pct > 50 else ("\033[93m" if pct > 20 else "\033[91m")
    reset = "\033[0m"
    return f"{color}[{bar}] %{pct:.1f}{reset}"

def print_cli():
    data, source = get_quota()
    if not data:
        print("\033[91m❌ Hata: Antigravity kota bilgisine ulaşılamadı. Antigravity uygulamasının açık olduğundan emin olun.\033[0m")
        sys.exit(1)

    now = datetime.now(timezone.utc)
    print("\033[1;36m╔══════════════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[1;36m║                  ⚡ ANTIGRAVITY ANLIK KOTA VE LİMİT TAKİBİ               ║\033[0m")
    print(f"\033[1;36m║                  Kaynak: {source:<48}║\033[0m")
    print("\033[1;36m╚══════════════════════════════════════════════════════════════════════════╝\033[0m")

    for g in data.get('groups', []):
        group_name = g.get('displayName', 'Bilinmeyen Grup')
        desc = g.get('description', '')
        print(f"\n\033[1;33m▶ {group_name}\033[0m \033[90m({desc})\033[0m")
        for b in g.get('buckets', []):
            name = b.get('displayName', 'Havuz')
            fraction = b.get('remainingFraction', 1.0)
            reset_str = b.get('resetTime')
            time_diff_sec = 0
            if reset_str:
                try:
                    dt = datetime.fromisoformat(reset_str.replace('Z', '+00:00'))
                    time_diff_sec = max(0, (dt - now).total_seconds())
                except Exception:
                    pass

            bar_str = make_bar(fraction, width=22)
            rem_time_str = format_duration(time_diff_sec)
            print(f"  • \033[1m{name:<28}\033[0m {bar_str}")
            print(f"    ↳ ⏱️  \033[37mKalan Süre:\033[0m \033[96m{rem_time_str}\033[0m  |  Hedef: \033[90m{reset_str}\033[0m")

    print("\n\033[90m──────────────────────────────────────────────────────────────────────────\033[0m")
    print(f"\033[90mSon Güncelleme: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} (Yerel Saat)\033[0m\n")

if __name__ == '__main__':
    if '--json' in sys.argv:
        data, source = get_quota()
        print(json.dumps({'source': source, 'data': data} if data else {'error': 'could not fetch quota'}))
    else:
        print_cli()
EOF
chmod +x "$INSTALL_DIR/agy-quota"

# 4.2 agy-hud-daemon (Canlı Enjeksiyon ve Senkronizasyon Servisi)
cat << 'EOF' > "$INSTALL_DIR/agy-hud-daemon"
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota HUD Daemon v3
Sohbet giriş kutusunun hemen üzerinde tek satır, dinamik kapsül şeklinde
canlı model kotasını, yüzdeleri ve sıfırlanma süresini gösterir.
"""

import asyncio
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import websockets

def get_cdp_port():
    paths = [
        os.path.expanduser('~/Library/Application Support/Antigravity/DevToolsActivePort'),
        os.path.expanduser('~/.config/Antigravity/DevToolsActivePort'),
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                with open(p, 'r') as f:
                    return int(f.readline().strip())
            except Exception:
                pass
    return None

def get_csrf():
    try:
        ps_out = subprocess.check_output(['ps', 'aux']).decode('utf-8')
        m_csrf = re.search(r'--csrf_token\s+([a-f0-9\-]+)', ps_out)
        return m_csrf.group(1) if m_csrf else ''
    except Exception:
        return ''

HUD_JS_TEMPLATE = """
(() => {
    const CSRF = __CSRF_TOKEN__;

    // 1. Eski banner ve kalıntıları temizle
    document.querySelectorAll('#antigravity-quota-hud, #test-quota-banner').forEach(e => e.remove());

    let lastPayload = null;
    let targetResetTime = null;

    function ensureBar() {
        const editor = document.querySelector('[contenteditable]');
        if (!editor) return null;
        const inputCard = editor.closest('.bg-card-border') || editor.closest('.bg-card');
        if (!inputCard || !inputCard.parentElement) return null;

        let bar = document.getElementById('chat-dock-quota-bar');
        if (bar && (bar.getAttribute('data-v') !== '3' || bar.nextElementSibling !== inputCard)) {
            bar.remove();
            bar = null;
        }

        if (!bar) {
            bar = document.createElement('div');
            bar.id = 'chat-dock-quota-bar';
            bar.setAttribute('data-v', '3');
            bar.style.cssText = `
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                width: fit-content;
                max-width: 100%;
                margin: 0 auto 6px auto;
                padding: 4px 12px;
                height: 26px;
                box-sizing: border-box;
                background: rgba(24, 24, 27, 0.85);
                backdrop-filter: blur(16px);
                -webkit-backdrop-filter: blur(16px);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 9999px;
                color: #e4e4e7;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                font-size: 11px;
                line-height: 1;
                white-space: nowrap;
                user-select: none;
                transition: border-color 0.2s, background 0.2s;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
            `;

            bar.addEventListener('mouseenter', () => {
                bar.style.borderColor = 'rgba(255, 255, 255, 0.15)';
            });
            bar.addEventListener('mouseleave', () => {
                bar.style.borderColor = 'rgba(255, 255, 255, 0.08)';
            });

            bar.innerHTML = `
                <span style="font-size:12px; line-height:1; display:inline-flex; align-items:center;">⚡</span>
                <span style="font-weight:600; color:#94a3b8; white-space:nowrap; line-height:1;">Gemini 5s:</span>
                <span id="dock-val-5h" style="font-weight:700; font-family:monospace; color:#34d399; font-size:11px; white-space:nowrap; line-height:1;">--%</span>
                <div id="dock-track-5h" style="width:36px; height:4px; background:rgba(255,255,255,0.08); border-radius:99px; overflow:hidden; flex-shrink:0;">
                    <div id="dock-fill-5h" style="width:100%; height:100%; background:linear-gradient(90deg, #10b981, #06b6d4); border-radius:99px; transition:width 0.4s ease;"></div>
                </div>
                <span style="color:rgba(255,255,255,0.12); margin:0 1px; line-height:1;">|</span>
                <span style="font-size:11px; line-height:1; display:inline-flex; align-items:center;">⏱️</span>
                <span id="dock-val-time" style="font-family:monospace; color:#fbbf24; font-weight:600; white-space:nowrap; line-height:1;">Hesaplanıyor...</span>
                <span style="color:rgba(255,255,255,0.12); margin:0 1px; line-height:1;">|</span>
                <span style="color:#71717a; white-space:nowrap; line-height:1;">Haftalık:</span>
                <span id="dock-val-weekly" style="font-family:monospace; color:#c084fc; font-weight:600; white-space:nowrap; line-height:1;">--%</span>
                <span style="color:rgba(255,255,255,0.12); margin:0 1px; line-height:1;">|</span>
                <span style="color:#71717a; white-space:nowrap; line-height:1;">Claude:</span>
                <span id="dock-val-claude" style="font-family:monospace; color:#34d399; font-weight:600; white-space:nowrap; line-height:1;">--%</span>
                <div id="dock-sync-status" title="Canlı otomatik senkronize ediliyor (Tıklayarak da yenileyebilirsiniz)" style="display:inline-flex; align-items:center; gap:4px; cursor:pointer; margin-left:2px;">
                    <span id="dock-sync-dot" style="width:5px; height:5px; border-radius:50%; background:#10b981; display:inline-block; box-shadow:0 0 4px rgba(16,185,129,0.5); transition:background 0.3s, transform 0.3s;"></span>
                    <span id="dock-sync-text" style="color:#71717a; font-size:10px; font-weight:500; line-height:1;">Canlı</span>
                </div>
            `;

            inputCard.parentElement.insertBefore(bar, inputCard);

            const syncStatus = document.getElementById('dock-sync-status');
            if (syncStatus) {
                syncStatus.addEventListener('click', (e) => {
                    e.stopPropagation();
                    fetchQuotaData();
                });
            }

            if (lastPayload) {
                renderUI(lastPayload);
                updateTick();
            }
        }
        return bar;
    }

    async function fetchQuotaData() {
        const dot = document.getElementById('dock-sync-dot');
        if (dot) {
            dot.style.background = '#38bdf8';
            dot.style.transform = 'scale(1.25)';
        }
        try {
            const res = await fetch('/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Codeium-Csrf-Token': CSRF
                },
                body: '{}'
            });
            const data = await res.json();
            lastPayload = data.response || data;
            renderUI(lastPayload);
            updateTick();
        } catch(e) {
            console.error('Quota fetch error:', e);
        } finally {
            if (dot) {
                setTimeout(() => {
                    dot.style.background = '#10b981';
                    dot.style.transform = 'scale(1)';
                }, 400);
            }
        }
    }

    function renderUI(payload) {
        let gemini5hPct = '%100';
        let geminiWeeklyPct = '%100';
        let claudePct = '%100';

        const groups = payload.groups || [];
        groups.forEach(g => {
            (g.buckets || []).forEach(b => {
                const pct = (b.remainingFraction * 100).toFixed(1);
                if (b.bucketId === 'gemini-5h') {
                    gemini5hPct = '%' + pct;
                    targetResetTime = new Date(b.resetTime).getTime();
                } else if (b.bucketId === 'gemini-weekly') {
                    geminiWeeklyPct = '%' + pct;
                } else if (b.bucketId === '3p-5h') {
                    claudePct = '%' + pct;
                }
            });
        });

        const dockVal5h = document.getElementById('dock-val-5h');
        const dockFill5h = document.getElementById('dock-fill-5h');
        const dockWeekly = document.getElementById('dock-val-weekly');
        const dockClaude = document.getElementById('dock-val-claude');

        if (dockVal5h) {
            dockVal5h.innerText = gemini5hPct;
            const num = parseFloat(gemini5hPct.replace('%',''));
            dockVal5h.style.color = num > 50 ? '#34d399' : (num > 20 ? '#fbbf24' : '#f87171');
        }
        if (dockFill5h) dockFill5h.style.width = gemini5hPct.replace('%','') + '%';
        if (dockWeekly) dockWeekly.innerText = geminiWeeklyPct;
        if (dockClaude) dockClaude.innerText = claudePct;
    }

    function updateTick() {
        if (!targetResetTime) return;
        const diff = targetResetTime - Date.now();
        const dockTime = document.getElementById('dock-val-time');

        let formatted = '00:00:00';
        let color = '#34d399';

        if (diff > 0) {
            const h = Math.floor(diff / (1000 * 60 * 60));
            const m = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
            const s = Math.floor((diff % (1000 * 60)) / 1000);
            formatted = `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
            color = '#fbbf24';
        }

        if (dockTime) {
            dockTime.innerText = formatted;
            dockTime.style.color = color;
        }
    }

    ensureBar();
    fetchQuotaData();

    if (!window.__agy_quota_v3_setup) {
        window.__agy_quota_v3_setup = true;
        setInterval(updateTick, 1000);
        setInterval(fetchQuotaData, 10000);
        window.addEventListener('focus', fetchQuotaData);

        const observer = new MutationObserver(() => {
            ensureBar();
        });
        observer.observe(document.body, { childList: true, subtree: true });
    }
})();
"""

async def cdp_eval(ws, expression):
    req_id = int(time.time() * 1000) % 1000000
    await ws.send(json.dumps({
        'id': req_id,
        'method': 'Runtime.evaluate',
        'params': {'expression': expression, 'returnByValue': True}
    }))
    start = time.time()
    while time.time() - start < 2.5:
        raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
        msg = json.loads(raw)
        if msg.get('id') == req_id:
            return msg.get('result', {}).get('result', {}).get('value')
    return None

async def run_daemon():
    print("Starting Antigravity Single-Line Quota HUD Daemon v3...", flush=True)
    while True:
        try:
            port = get_cdp_port()
            csrf = get_csrf()
            if port and csrf:
                code_to_inject = HUD_JS_TEMPLATE.replace('__CSRF_TOKEN__', json.dumps(csrf))
                req = urllib.request.urlopen(f'http://127.0.0.1:{port}/json', timeout=1.5)
                pages = json.loads(req.read().decode('utf-8'))
                for p in pages:
                    if p.get('type') != 'page':
                        continue
                    ws_url = p.get('webSocketDebuggerUrl')
                    if ws_url:
                        try:
                            async with websockets.connect(ws_url, open_timeout=1.5, close_timeout=1.0) as ws:
                                # Ensure v3 dock bar exists and legacy elements are removed
                                check_expr = '!!document.getElementById("chat-dock-quota-bar") && document.getElementById("chat-dock-quota-bar").getAttribute("data-v") === "3" && !document.getElementById("antigravity-quota-hud") && !document.getElementById("test-quota-banner")'
                                is_clean = await cdp_eval(ws, check_expr)
                                if not is_clean:
                                    await cdp_eval(ws, code_to_inject)
                                    print(f"Updated Quota Bar v3 on: {p.get('title')}", flush=True)
                        except Exception:
                            pass
        except Exception:
            pass
        await asyncio.sleep(2)

if __name__ == '__main__':
    asyncio.run(run_daemon())

EOF
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
# 5. macOS LAUNCHAGENT SERVİSİ
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/4] Arka plan servisi (LaunchAgent) yapılandırılıyor...${NC}"
mkdir -p "$LAUNCH_AGENTS_DIR"

PYTHON_BIN=$(command -v python3)
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
echo -e "${GREEN}✓ 'com.antigravity.hud' arka plan servisi başlatıldı.${NC}"

# ------------------------------------------------------------------------------
# 6. ANTIGRAVITY EKLENTİSİ (/quota)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/4] Antigravity '/quota' slash komutu kuruluyor...${NC}"
mkdir -p "$PLUGIN_DIR/skills/quota-monitor"

cat << 'EOF' > "$PLUGIN_DIR/plugin.json"
{
  "name": "antigravity-quota-monitor",
  "version": "1.0.0",
  "description": "Antigravity anlık model kotaları, kullanım oranları ve sıfırlanma süresi takip eklentisi",
  "author": {
    "name": "Uğur Hoca"
  },
  "license": "MIT"
}
EOF

cat << 'EOF' > "$PLUGIN_DIR/skills/quota-monitor/SKILL.md"
---
name: quota-monitor
description: "Antigravity anlık model kotalarını, 5 saatlik ve haftalık havuz kullanım oranlarını ve sıfırlanmaya kalan süreyi dinamik olarak sorgulayan ve canlı görselleştiren uzmanlık becerisi. Kullanıcı '/quota', '/limitler' veya kota durumunu sorduğunda devreye girer."
---

# Antigravity Kota ve Limit Takip Becerisi ⚡

Bu beceri, Antigravity uygulamasının içindeki yerel LanguageServer RPC ve CloudCode servislerine bağlanarak anlık model kotalarını, kalan limit yüzdelerini ve havuz sıfırlanma sürelerini kullanıcıya canlı olarak sunar.

## Kullanım Tetikleyicileri
- Kullanıcı `/quota`, `/limitler` veya `/kotalar` komutunu çalıştırdığında
- Kullanıcı limit durumunu, ne kadar hakkı kaldığını veya ne zaman sıfırlanacağını sorduğunda

## Veri Çekme Yöntemi
```bash
agy-quota --json
```
EOF
echo -e "${GREEN}✓ Antigravity eklentisi başarıyla entegre edildi.${NC}"

echo -e "\n${GREEN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 TEBRİKLER! Kurulum başarıyla tamamlandı.${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "Şimdi neler yapabilirsiniz:"
echo -e " 1. ${CYAN}Sohbet Ekranı:${NC} Antigravity penceresine geçin; yazma kutusunun üstünde canlı bar görünecektir."
echo -e " 2. ${CYAN}Terminalden Takip:${NC} Terminalde ${YELLOW}agy-quota${NC} yazarak renkli kota grafiğini görün."
echo -e " 3. ${CYAN}Sohbet İçinde:${NC} Sohbet kutusuna ${YELLOW}/quota${NC} yazarak limitlerinizi asistana sorabilirsiniz."
echo ""
