#!/usr/bin/env python3
"""Riassume i report JSON di GoTestWAF di una cartella, uno per riga."""
import glob
import json
import os
import sys

for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    s = json.load(open(f))["summary"]
    tp, tn = s["true_positive_tests"]["summary"], s["true_negative_tests"]["summary"]
    pct = lambda d: 100 * d["blocked_tests"] / max(d["resolved_tests"], 1)
    print(f"  {os.path.basename(f)[:-5]:9} attacchi bloccati {tp['blocked_tests']:3}/{tp['resolved_tests']} ({pct(tp):4.1f}%)"
          f"   legittime bloccate {tn['blocked_tests']:3}/{tn['resolved_tests']} ({pct(tn):4.1f}%)")
