#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Quota Monitor birim testleri.
"""

import sys
import os
import io
import json
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

def test_format_duration():
    # Sıfır veya negatif
    assert "Sıfırlandı" in agy_quota.format_duration(0)
    assert "Sıfırlandı" in agy_quota.format_duration(-10)

    # 1 saat 30 dakika 15 saniye
    formatted = agy_quota.format_duration(5415)
    assert "01:30:15" in formatted
    assert "1 sa 30 dk 15 sn" in formatted

    # 2 günden fazla süre
    long_formatted = agy_quota.format_duration(200000)
    assert "gün" in long_formatted
    assert "2 gün" in long_formatted

def test_make_bar():
    # %100 - Yeşil
    bar_full = agy_quota.make_bar(1.0, width=10)
    assert "██████████" in bar_full
    assert "%100.0" in bar_full
    assert "\033[92m" in bar_full  # Yeşil ANSI

    # %50 - Sarı
    bar_half = agy_quota.make_bar(0.5, width=10)
    assert "█████░░░░░" in bar_half
    assert "%50.0" in bar_half

    # %10 - Kırmızı
    bar_low = agy_quota.make_bar(0.1, width=10)
    assert "█░░░░░░░░░" in bar_low
    assert "%10.0" in bar_low
    assert "\033[91m" in bar_low  # Kırmızı ANSI

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
    # lsof başarısız olduğunda ss çıktısı
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
