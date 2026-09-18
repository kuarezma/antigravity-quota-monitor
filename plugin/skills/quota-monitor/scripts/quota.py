#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota Monitor CLI / Asistan Becerisi
Yerel LanguageServer RPC veya CloudCode API üzerinden kota sorgular.
"""

import sys
import os
import importlib.util

# 1. Öncelikle repodaki veya sistemdeki agy-quota çekirdeğini kullanmayı dene
script_dir = os.path.dirname(os.path.abspath(__file__))
repo_bin = os.path.abspath(os.path.join(script_dir, '../../../../bin/agy-quota'))
local_bin = os.path.expanduser('~/.local/bin/agy-quota')

for candidate in [repo_bin, local_bin]:
    if os.path.isfile(candidate):
        try:
            spec = importlib.util.spec_from_file_location("agy_quota_core", candidate)
            if spec and spec.loader:
                core = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(core)
                if __name__ == '__main__':
                    if '--json' in sys.argv:
                        data, source = core.get_quota()
                        import json
                        if data:
                            print(json.dumps({'source': source, 'data': data}, indent=2, ensure_ascii=False))
                        else:
                            print(json.dumps({'error': 'could not fetch quota'}))
                            sys.exit(1)
                    else:
                        core.print_cli()
                sys.exit(0)
        except Exception:
            pass

# 2. İzolasyon durumunda güvenli yedek (Fallback) implementasyonu
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
                    parts = line.split()
                    if len(parts) > 1:
                        target_pid = parts[1]
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

        for port in set(ports):
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
        if not os.path.exists(token_path):
            return None

        with open(token_path, 'r', encoding='utf-8') as f:
            tok_data = json.load(f)

        access_token = tok_data.get('token', {}).get('access_token')
        if not access_token:
            return None

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

def print_cli():
    data, source = get_quota()
    if not data:
        print("\033[91m❌ Hata: Antigravity kota bilgisine ulaşılamadı.\033[0m")
        sys.exit(1)
    print(json.dumps({'source': source, 'data': data}, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    if '--json' in sys.argv:
        data, source = get_quota()
        if data:
            print(json.dumps({'source': source, 'data': data}, indent=2, ensure_ascii=False))
        else:
            print(json.dumps({'error': 'could not fetch quota'}))
            sys.exit(1)
    else:
        print_cli()
