#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota Monitor CLI (agy-quota)
Anlık model kotası, kalan yüzdeler ve sıfırlanma süresi takipçisi.
"""

import sys
import subprocess
import re
import json
import urllib.request
import ssl
from datetime import datetime, timezone

def fetch_quota_language_server():
    """Antigravity yerel LanguageServer RPC üzerinden kota bilgisini çeker."""
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
    """Antigravity CloudCode API uç noktası üzerinden kota çeker."""
    try:
        with open('/Users/ugurmac/.gemini/jetski-standalone-oauth-token', 'r') as f:
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

def make_bar(fraction, width=20):
    filled = int(round(fraction * width))
    bar = "█" * filled + "░" * (width - filled)
    pct = fraction * 100
    if pct > 50:
        color = "\033[92m" # Green
    elif pct > 20:
        color = "\033[93m" # Yellow
    else:
        color = "\033[91m" # Red
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
        if data:
            print(json.dumps({'source': source, 'data': data}, indent=2))
        else:
            print(json.dumps({'error': 'could not fetch quota'}))
    else:
        print_cli()
