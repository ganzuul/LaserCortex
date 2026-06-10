"""
QCSignalAdapter — bridge a QuantConnect-style signal pipeline through LaserCortex.

Replays a canonical MA-cross strategy (15/30 EMA) against historical price data,
maps each signal decision to a ``CortexSpec`` witness, instantiates it through the
bridge, and produces a verifiable certificate chain.

Usage::

    from infra._cortex._qc_adapter import QCSignalAdapter
    from infra._cortex import NormCodeCortexBridge

    bridge = NormCodeCortexBridge()
    adapter = QCSignalAdapter(bridge, symbol="SPY")
    result = adapter.run(spec_name="sorites_threshold",
                         start="2020-01-01", end="2023-12-31")
    print(result["summary"])
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple
import logging
import time

import pandas as pd
import numpy as np

from infra._cortex import NormCodeCortexBridge, SEED_REGISTRY, CortexCertificate

logger = logging.getLogger(__name__)


# ── Config ────────────────────────────────────────────────────────────

@dataclass
class SignalConfig:
    """Parameters for the MA-cross signal logic (canonical QC template)."""
    fast_window: int = 15
    slow_window: int = 30
    tolerance: float = 0.00015       # 1.5 bp guard band
    price_field: str = "Close"       # column name in the OHLCV DataFrame
    use_adjusted: bool = True        # use adjusted close


# ── Result types ──────────────────────────────────────────────────────

@dataclass
class SignalEvent:
    """A single signal event with its LC certificate."""
    bar_index: int
    timestamp: str
    price: float
    fast_ma: float
    slow_ma: float
    signal: str                     # "enter_long" | "exit_long" | "hold"
    position: float                 # quantity after this bar
    witness_data: Dict[str, Any]
    certificate: CortexCertificate
    verified: bool


@dataclass
class BacktestResult:
    """Full result of a QC adapter run."""
    spec_name: str
    symbol: str
    total_bars: int
    signal_events: List[SignalEvent]
    certificates: Dict[str, CortexCertificate]
    voyage_certificate: Optional[CortexCertificate]
    checkpoint_certificates: Dict[str, CortexCertificate]
    all_verified: bool
    summary: Dict[str, Any]


# ── Adapter ───────────────────────────────────────────────────────────

class QCSignalAdapter:
    """Replay a QC-style signal strategy and certify every decision."""

    def __init__(
        self,
        bridge: NormCodeCortexBridge,
        symbol: str = "SPY",
        config: Optional[SignalConfig] = None,
    ):
        self.bridge = bridge
        self.symbol = symbol
        self.config = config or SignalConfig()
        self._run_id: Optional[str] = None

    # ── Public API ──────────────────────────────────────────────────

    def run(
        self,
        spec_name: str = "sorites_threshold",
        start: str = "2020-01-01",
        end: str = "2023-12-31",
        checkpoint_every: int = 63,        # ~quarterly
    ) -> BacktestResult:
        """Fetch data, replay the signal pipeline, certify every decision.

        Returns a ``BacktestResult`` with the full certificate chain.
        """
        import yfinance as yf

        logger.info("Fetching %s %s .. %s", self.symbol, start, end)
        df = yf.download(self.symbol, start=start, end=end,
                         auto_adjust=self.config.use_adjusted,
                         progress=False)
        if df.empty:
            raise ValueError(f"No data for {self.symbol} in range {start}–{end}")

        return self.run_from_dataframe(df, spec_name=spec_name,
                                       checkpoint_every=checkpoint_every)

    def run_from_dataframe(
        self,
        df: pd.DataFrame,
        spec_name: str = "sorites_threshold",
        checkpoint_every: int = 63,
    ) -> BacktestResult:
        """Run the pipeline against an already-loaded DataFrame."""
        spec = SEED_REGISTRY.lookup(spec_name)
        if spec is None:
            raise ValueError(f"Unknown spec '{spec_name}'")

        cfg = self.config
        price_col = cfg.price_field
        if price_col not in df.columns:
            raise KeyError(f"DataFrame has no '{price_col}' column; "
                           f"got {list(df.columns)}")

        # Compute indicators
        fast = df[price_col].ewm(span=cfg.fast_window, adjust=False).mean()
        slow = df[price_col].ewm(span=cfg.slow_window, adjust=False).mean()

        position = 0.0
        signal_events: List[SignalEvent] = []
        run_id = f"qc:{self.symbol}:{spec_name}"

        logger.info("Replaying %d bars with %d/%d MA cross",
                     len(df), cfg.fast_window, cfg.slow_window)

        for i in range(len(df)):
            row = df.iloc[i]
            ts = str(row.name) if hasattr(row.name, 'isoformat') else str(row.name)
            fv = float(fast.iloc[i].iloc[0] if hasattr(fast.iloc[i], 'iloc') else fast.iloc[i])
            sv = float(slow.iloc[i].iloc[0] if hasattr(slow.iloc[i], 'iloc') else slow.iloc[i])
            px = float(row[price_col].iloc[0] if hasattr(row[price_col], 'iloc') else row[price_col])

            # Skip until indicators are ready
            if pd.isna(fv) or pd.isna(sv):
                continue

            signal = "hold"
            new_position = position

            if position <= 0 and fv > sv * (1 + cfg.tolerance):
                signal = "enter_long"
                new_position = 1.0
            elif position > 0 and fv < sv:
                signal = "exit_long"
                new_position = 0.0

            # Map to witness data  (price in cents = integer witness)
            witness: Dict[str, Any] = {
                "witness": int(round(px * 100)),          # cents → integer
                "fast_ma": round(fv, 4),
                "slow_ma": round(sv, 4),
                "price": round(px, 4),
                "signal": signal,
                "position": new_position,
                "spread_bp": round((fv / sv - 1) * 10000, 2),
            }

            # Push through the bridge
            concept, cert = self.bridge.instantiate_spec(spec, witness)
            verified = cert.verify()

            event = SignalEvent(
                bar_index=i,
                timestamp=ts,
                price=px,
                fast_ma=fv,
                slow_ma=sv,
                signal=signal,
                position=new_position,
                witness_data=witness,
                certificate=cert,
                verified=verified,
            )
            signal_events.append(event)

            # Stamp into the bridge's lift cache
            self.bridge.on_inference_complete(
                flow_index=str(i),
                concept=concept,
                sequence_type="qc_signal",
                run_id=run_id,
            )

            position = new_position

            if i > 0 and i % 100 == 0:
                logger.info("  processed %d/%d bars", i, len(df))

        logger.info("Signal replay complete — %d events", len(signal_events))

        # Stamp voyage seal
        voyage_cert = self.bridge.stamp_seal(run_id)

        # Stamp periodic checkpoints
        checkpoint_certs: Dict[str, CortexCertificate] = {}
        for cycle in range(1, len(signal_events) // checkpoint_every + 1):
            cc = self.bridge.stamp_checkpoint(run_id, cycle)
            if cc:
                checkpoint_certs[str(cycle)] = cc

        # Verify everything
        all_verified = all(e.verified for e in signal_events)

        total_trades = sum(1 for e in signal_events if e.signal != "hold")
        summary = {
            "spec": spec_name,
            "symbol": self.symbol,
            "run_id": run_id,
            "total_bars": len(signal_events),
            "total_trades": total_trades,
            "all_signals_verified": all_verified,
            "voyage_verified": voyage_cert.verify() if voyage_cert else False,
            "checkpoints": len(checkpoint_certs),
            "certificates_issued": len(signal_events),
        }

        return BacktestResult(
            spec_name=spec_name,
            symbol=self.symbol,
            total_bars=len(signal_events),
            signal_events=signal_events,
            certificates={},
            voyage_certificate=voyage_cert,
            checkpoint_certificates=checkpoint_certs,
            all_verified=all_verified,
            summary=summary,
        )

    def verify_backtest(self, result: BacktestResult) -> Dict[str, Any]:
        """Post-hoc verification of the entire certificate chain."""
        issues = []
        for ev in result.signal_events:
            if not ev.verified:
                issues.append(f"bar {ev.bar_index}: cert.verify() failed")

        voyage_ok = False
        if result.voyage_certificate:
            voyage_ok = result.voyage_certificate.verify()
            if not voyage_ok:
                issues.append("voyage seal verification failed")

        checkpoint_results = {}
        for cycle, cert in result.checkpoint_certificates.items():
            ck = cert.verify()
            checkpoint_results[cycle] = ck
            if not ck:
                issues.append(f"checkpoint {cycle}: verify failed")

        return {
            "passed": len(issues) == 0,
            "issues": issues,
            "voyage_verified": voyage_ok,
            "checkpoints_verified": checkpoint_results,
            "total_signals": result.total_bars,
            "failed_signals": sum(1 for e in result.signal_events if not e.verified),
        }
