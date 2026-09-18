#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota Monitor birim testleri.
"""

import sys
import os
import io
import json
import time
import importlib.util
from importlib.machinery import SourceFileLoader
from unittest.mock import patch, MagicMock, mock_open

# bin/agy-quota modülünü dinamik yükle
bin_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../bin/agy-quota'))
loader = SourceFileLoader("agy_quota", bin_path)
spec = importlib.util.spec_from_loader("agy_quota", loader)
agy_quota = importlib.util.module_from_spec(spec)
loader.exec_module(agy_quota)

# bin/agy-hud-daemon modülünü dinamik yükle
daemon_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../bin/agy-hud-daemon'))
loader_d = SourceFileLoader("agy_daemon", daemon_path)
spec_d = importlib.util.spec_from_loader("agy_daemon", loader_d)
agy_daemon = importlib.util.module_from_spec(spec_d)
loader_d.exec_module(agy_daemon)

def test_format_duration_tr_en():
    # TR formatı
    assert "Sıfırlandı" in agy_quota.format_duration(0, lang='tr')
    formatted_tr = agy_quota.format_duration(5415, lang='tr')
    assert "1 sa 30 dk 15 sn" in formatted_tr

    # EN formatı
    assert "Refreshed" in agy_quota.format_duration(0, lang='en')
    formatted_en = agy_quota.format_duration(5415, lang='en')
    assert "1 h 30 m 15 s" in formatted_en

def test_format_minutes_left():
    assert agy_quota.format_minutes_left(None) == ""
    assert "45 dk" in agy_quota.format_minutes_left(45, lang='tr')
    assert "45 m" in agy_quota.format_minutes_left(45, lang='en')
    assert "1 sa 15 dk" in agy_quota.format_minutes_left(75, lang='tr')
    assert "1 h 15 m" in agy_quota.format_minutes_left(75, lang='en')

def test_make_bar():
    # %100 - Yeşil
    bar_full = agy_quota.make_bar(1.0, width=10)
    assert "██████████" in bar_full
    assert "%100.0" in bar_full
    assert "\033[92m" in bar_full

    # %50 - Sarı
    bar_half = agy_quota.make_bar(0.5, width=10)
    assert "█████░░░░░" in bar_half
    assert "%50.0" in bar_half

    # %10 - Kırmızı
    bar_low = agy_quota.make_bar(0.1, width=10)
    assert "█░░░░░░░░░" in bar_low
    assert "%10.0" in bar_low
    assert "\033[91m" in bar_low

    # Sınır dışı değerler (clamping)
    bar_neg = agy_quota.make_bar(-0.5, width=10)
    assert "%0.0" in bar_neg
    bar_over = agy_quota.make_bar(1.5, width=10)
    assert "%100.0" in bar_over

def test_get_listening_ports_lsof():
    fake_lsof = (
        "COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME\n"
        "language_ 1234 test   12u  IPv4 0x12345678      0t0  TCP 127.0.0.1:49215 (LISTEN)\n"
        "language_ 1234 test   14u  IPv6 0x12345679      0t0  TCP [::1]:49216 (LISTEN)\n"
    )
    with patch('subprocess.check_output', return_value=fake_lsof.encode('utf-8')):
        ports = agy_quota.get_listening_ports(1234)
        assert 49215 in ports
        assert 49216 in ports

def test_get_listening_ports_ss_linux():
    fake_ss = (
        "State      Recv-Q Send-Q Local Address:Port Peer Address:PortProcess\n"
        "LISTEN     0      128    127.0.0.1:38421     0.0.0.0:*    users:((\"language_server\",pid=5678,fd=7))\n"
    )
    with patch('subprocess.check_output') as mock_sub:
        def side_effect(cmd, **kwargs):
            if cmd[0] == 'lsof':
                raise FileNotFoundError("lsof not installed")
            if cmd[0] == 'ss':
                return fake_ss.encode('utf-8')
            return b""
        mock_sub.side_effect = side_effect
        ports = agy_quota.get_listening_ports(5678)
        assert 38421 in ports

def test_fetch_quota_cloud_api(mock_quota_summary):
    fake_token = json.dumps({"token": {"access_token": "fake_secret_token"}})
    fake_api_resp = io.BytesIO(json.dumps(mock_quota_summary).encode('utf-8'))

    with patch('os.path.exists', return_value=True), \
         patch('builtins.open', mock_open(read_data=fake_token)), \
         patch('urllib.request.urlopen', return_value=fake_api_resp):
        result = agy_quota.fetch_quota_cloud_api()
        assert result is not None
        assert "groups" in result
        assert len(result["groups"]) == 2

def test_fetch_quota_language_server(mock_quota_summary):
    fake_ps = "user 9999 0.0 0.1 123 456 ? Sl 00:00 /path/to/language_server --csrf_token abc-123-def\n"
    fake_api_resp = io.BytesIO(json.dumps({"response": mock_quota_summary}).encode('utf-8'))

    with patch('subprocess.check_output', return_value=fake_ps.encode('utf-8')), \
         patch.object(agy_quota, 'get_listening_ports', return_value=[49215]), \
         patch('urllib.request.urlopen', return_value=fake_api_resp):
        result = agy_quota.fetch_quota_language_server()
        assert result is not None
        assert "groups" in result
        assert len(result["groups"]) == 2

def test_calculate_burn_rate():
    # 1. Yetersiz geçmiş -> idle
    res_idle = agy_quota.calculate_burn_rate("gemini-5h", 0.9, history={'buckets': {}})
    assert res_idle['status'] == 'idle'

    # 2. Aktif tüketim: 30 dakika önce 0.95 olan kota şimdi 0.85 (fark = 0.10, 0.5 saatte %10 -> %20/saat)
    now_ts = int(time.time())
    hist = {
        'buckets': {
            'gemini-5h': [
                {'ts': now_ts - 1800, 'fraction': 0.95},
                {'ts': now_ts, 'fraction': 0.85}
            ]
        }
    }
    res_active = agy_quota.calculate_burn_rate("gemini-5h", 0.85, history=hist)
    assert res_active['status'] == 'active'
    assert res_active['rate_per_hour'] == 20.0
    assert res_active['minutes_left'] > 0

def test_quota_alert_manager(mock_quota_summary):
    alert_mgr = agy_daemon.QuotaAlertManager()
    with patch.object(agy_daemon, 'send_desktop_notification') as mock_notify:
        # 1. Havuz %4 -> %5 uyarısı tetiklenmeli
        alert_mgr.check_and_alert(mock_quota_summary)
        assert mock_notify.called
        call_args = mock_notify.call_args[0]
        assert "%5" in call_args[0]
        assert "Five Hour Limit Remaining" in call_args[1]

        mock_notify.reset_mock()
        # 2. İkinci çağrıda tekrar spam yapmamalı
        alert_mgr.check_and_alert(mock_quota_summary)
        assert not mock_notify.called

        # 3. Kota dolduğunda (> %75) bildirim durumu sıfırlanmalı
        mock_quota_summary["groups"][1]["buckets"][1]["remainingFraction"] = 0.90
        alert_mgr.check_and_alert(mock_quota_summary)
        assert len(alert_mgr.alerted_levels.get("3p-5h", set())) == 0
