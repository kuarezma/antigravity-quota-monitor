#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test fikstürleri ve sahte (mock) API verileri.
"""

import pytest

@pytest.fixture
def mock_quota_summary():
    return {
        "groups": [
            {
                "displayName": "Gemini Models",
                "description": "Models within this group: Gemini Flash, Gemini Pro",
                "buckets": [
                    {
                        "bucketId": "gemini-weekly",
                        "displayName": "Weekly Limit Remaining",
                        "description": "You have used some of your weekly limit.",
                        "window": "weekly",
                        "remainingFraction": 0.85,
                        "resetTime": "2026-09-24T18:48:53Z"
                    },
                    {
                        "bucketId": "gemini-5h",
                        "displayName": "Five Hour Limit Remaining",
                        "description": "You have used some of your 5-hour limit.",
                        "window": "5h",
                        "remainingFraction": 0.95,
                        "resetTime": "2026-09-19T03:12:45Z"
                    }
                ]
            },
            {
                "displayName": "Claude and GPT models",
                "description": "Models within this group: Claude Opus, Claude Sonnet, GPT-OSS",
                "buckets": [
                    {
                        "bucketId": "3p-weekly",
                        "displayName": "Weekly Limit Remaining",
                        "window": "weekly",
                        "remainingFraction": 1.0,
                        "resetTime": "2026-09-25T22:19:48Z"
                    },
                    {
                        "bucketId": "3p-5h",
                        "displayName": "Five Hour Limit Remaining",
                        "window": "5h",
                        "remainingFraction": 0.04,
                        "resetTime": "2026-09-19T03:19:48Z"
                    }
                ]
            }
        ]
    }
