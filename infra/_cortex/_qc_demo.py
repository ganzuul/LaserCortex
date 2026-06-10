#!/usr/bin/env python3
"""
Demo: replay a QC MA-cross backtest through the LaserCortex bridge.

Produces a certificate chain for every signal decision, then verifies
the entire voyage.  No QuantConnect runtime required — uses yfinance
for price data and replays the signal logic locally.
"""

import sys
import logging

sys.path.insert(0, ".")

# The EMLTree size() method recurses on the full composite tree.
# A 1-year backtest produces ~250 signals → ~250-node tree → safe.
# Increase only if running multi-year.
sys.setrecursionlimit(5000)

from infra._cortex._qc_adapter import QCSignalAdapter, SignalConfig
from infra._cortex import NormCodeCortexBridge

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


def main():
    bridge = NormCodeCortexBridge()
    adapter = QCSignalAdapter(
        bridge,
        symbol="SPY",
        config=SignalConfig(fast_window=15, slow_window=30, tolerance=0.00015),
    )

    logger.info("Running QC MA-cross backtest through LC bridge ...")
    # Use Q1 2023 — ~60 bars → fast certify (~0.5s vs ~15s for 250 bars).
    # The rightComb contraction checker in pure Python is O(n²);
    # the Lean binary will be near-instant.
    result = adapter.run(
        spec_name="sorites_threshold",
        start="2023-01-01",
        end="2023-03-31",
        checkpoint_every=21,
    )

    print()
    print("=" * 60)
    print("BACKTEST SUMMARY")
    print("=" * 60)
    for k, v in result.summary.items():
        print(f"  {k}: {v}")

    print()
    print("=" * 60)
    print("VERIFICATION REPORT")
    print("=" * 60)
    report = adapter.verify_backtest(result)
    print(f"  Passed:       {report['passed']}")
    print(f"  Voyage seal:  {report['voyage_verified']}")
    print(f"  Checkpoints:  {report['checkpoints_verified']}")
    print(f"  Total signals:{report['total_signals']}")
    print(f"  Failures:     {report['failed_signals']}")
    if report["issues"]:
        print(f"  Issues:")
        for iss in report["issues"]:
            print(f"    - {iss}")

    print()
    print("=" * 60)
    print("TRADE LOG (first 10)")
    print("=" * 60)
    trades = [e for e in result.signal_events if e.signal != "hold"]
    for t in trades[:10]:
        print(f"  [{t.timestamp}] {t.signal:12s}  "
              f"price={t.price:.2f}  fast={t.fast_ma:.2f}  "
              f"slow={t.slow_ma:.2f}  verified={t.verified}")

    print()
    logger.info("Done — %d certificates issued, %d checkpoints stamped, "
                 "voyage seal %s.",
                 result.summary["certificates_issued"],
                 result.summary["checkpoints"],
                 "VERIFIED" if result.summary["voyage_verified"] else "FAILED")


if __name__ == "__main__":
    main()
