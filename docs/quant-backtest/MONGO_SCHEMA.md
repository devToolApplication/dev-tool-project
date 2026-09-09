# MongoDB Schema — Quant Backtest Service v1

## 1. Design principles

- 1m OHLCV is the canonical market data source.
- Higher timeframes are derived from the 1m stream for the backtest path.
- Strategy source is Python code selected by a stable `strategy_id`.
- **There is no strategy versioning model.** No `strategy_version`, `strategy_versions`, `gitCommit` or `activeVersion` fields are part of the business contract.
- Strategy behavior is controlled by a **persisted strategy configuration** in MongoDB.
- A backtest run stores the `strategy_config_id` and a snapshot of the configuration actually used, so the run remains auditable even if the live configuration document is later edited.
- Large result artifacts should not be embedded in a single MongoDB document.

---

## 2. `market_bars_1m`

Canonical 1-minute OHLCV.

```json
{
  "symbol": "BTCUSDT",
  "timestamp": "2026-09-09T10:00:00Z",
  "open": 112000.10,
  "high": 112120.20,
  "low": 111940.00,
  "close": 112080.30,
  "volume": 124.7,
  "source": "provider-x",
  "dataset_version": "2026-09-09-v1"
}
```

Required validation:

- `high >= max(open, close)`
- `low <= min(open, close)`
- volume must be non-negative
- timestamps normalized to UTC
- no duplicate `(symbol, timestamp, dataset_version)`

Recommended index:

```javascript
db.market_bars_1m.createIndex(
  { symbol: 1, timestamp: 1, dataset_version: 1 },
  { unique: true }
)
```

---

## 3. `market_datasets`

Dataset metadata used to identify the market-data input.

```json
{
  "dataset_version": "BTCUSDT-20260901-v1",
  "source": "provider-x",
  "symbols": ["BTCUSDT"],
  "timeframe": "1m",
  "start": "2025-01-01T00:00:00Z",
  "end": "2026-09-01T00:00:00Z",
  "bar_count": 865000,
  "timezone": "UTC",
  "status": "READY",
  "created_at": "2026-09-01T02:00:00Z"
}
```

---

## 4. `strategies`

Logical strategy registry. The source code for each strategy is maintained in the application repository.

```json
{
  "strategy_id": "ict_liquidity_reversal",
  "name": "ICT Liquidity Reversal",
  "description": "Liquidity sweep + structure shift + FVG entry",
  "status": "ACTIVE"
}
```

No version field is required.

---

## 5. `strategy_configs`

The **configuration is the only strategy configuration identity exposed to the backtest API**.

The document selects a strategy and stores all runtime/business parameters required by that strategy.

```json
{
  "config_id": "CFG-ICT-LR-001",
  "strategy_id": "ict_liquidity_reversal",
  "name": "BTC 5m London reversal",
  "description": "Sweep + CHOCH + FVG setup",
  "status": "ACTIVE",
  "parameters": {
    "swing_lookback": 3,
    "risk_per_trade": 0.01,
    "fvg_min_size_atr": 0.25,
    "session": "LONDON"
  },
  "data_requirements": {
    "base_timeframe": "1m",
    "timeframes": ["1m", "5m", "15m", "1h", "4h"]
  },
  "simulation": {
    "intrabar_level": 3,
    "intrabar_policy": "LOWER_TIMEFRAME_FIRST_AVAILABLE",
    "fee_model": "configured-model",
    "slippage_model": "configured-model"
  },
  "created_at": "2026-09-09T01:00:00Z",
  "updated_at": "2026-09-09T01:00:00Z"
}
```

### Configuration rules

1. `config_id` is stable and unique.
2. Strategy source is resolved by `strategy_id`.
3. Parameters are stored in MongoDB, not hard-coded into the strategy class.
4. A configuration used by a completed run should be treated as immutable operationally. If a user needs materially different behavior, create another configuration document rather than editing historical meaning.
5. This is **configuration management, not strategy versioning**.

Recommended indexes:

```javascript
db.strategy_configs.createIndex({ config_id: 1 }, { unique: true })
db.strategy_configs.createIndex({ strategy_id: 1, status: 1 })
```

---

## 6. `backtest_runs`

The reproducibility/audit anchor.

```json
{
  "run_id": "BT-20260909-000001",
  "status": "COMPLETED",
  "strategy_id": "ict_liquidity_reversal",
  "strategy_config_id": "CFG-ICT-LR-001",
  "strategy_config_snapshot": {
    "parameters": {
      "swing_lookback": 3,
      "risk_per_trade": 0.01,
      "fvg_min_size_atr": 0.25,
      "session": "LONDON"
    },
    "data_requirements": {
      "base_timeframe": "1m",
      "timeframes": ["1m", "5m", "15m", "1h", "4h"]
    },
    "simulation": {
      "intrabar_level": 3,
      "intrabar_policy": "LOWER_TIMEFRAME_FIRST_AVAILABLE",
      "fee_model": "configured-model",
      "slippage_model": "configured-model"
    }
  },
  "dataset_version": "BTCUSDT-20260901-v1",
  "symbols": ["BTCUSDT"],
  "start": "2025-01-01T00:00:00Z",
  "end": "2025-12-31T23:59:00Z",
  "base_timeframe": "1m",
  "initial_capital": 100000,
  "created_at": "2026-09-09T02:00:00Z",
  "completed_at": "2026-09-09T02:05:00Z"
}
```

### Important

The run stores a **configuration snapshot**, not a strategy version. This protects reproducibility when the MongoDB configuration document is subsequently edited.

Reproducibility is based on:

```text
Strategy ID
+ persisted configuration snapshot
+ dataset version
+ symbol(s)
+ date range
+ base timeframe
+ simulation configuration
+ backtest engine/runtime metadata
```

Because strategy source is not versioned as part of the strategy contract, a deployment that changes the Python implementation of the same `strategy_id` can change results. That is an operational deployment concern rather than a strategy-versioning concept in this design.

---

## 7. `backtest_metrics`

Summary metrics for fast API/UI retrieval.

```json
{
  "run_id": "BT-20260909-000001",
  "total_return": 0.31,
  "cagr": 0.29,
  "sharpe": 1.72,
  "sortino": 2.41,
  "max_drawdown": -0.14,
  "win_rate": 0.58,
  "profit_factor": 1.83,
  "total_trades": 347
}
```

---

## 8. `backtest_trades`

One document per executed simulated trade.

```json
{
  "run_id": "BT-20260909-000001",
  "trade_id": "T-000001",
  "symbol": "BTCUSDT",
  "side": "BUY",
  "entry_time": "2025-03-05T08:35:00Z",
  "entry_price": 103420,
  "exit_time": "2025-03-05T12:15:00Z",
  "exit_price": 105100,
  "quantity": 0.5,
  "pnl": 840,
  "fees": 12.5,
  "reason": [
    "sell_side_liquidity_sweep",
    "bullish_choch",
    "fvg_retest"
  ]
}
```

---

## 9. `backtest_orders`

Simulated order lifecycle for debugging execution behavior.

---

## 10. `backtest_signals`

Persist strategy-emitted signals to make the strategy decision trace inspectable.

---

## 11. `backtest_equity`

Equity samples. For large curves, sample at a configurable interval rather than one MongoDB document per event.

---

## 12. Index strategy

At minimum:

```javascript
db.backtest_runs.createIndex({ run_id: 1 }, { unique: true })
db.backtest_runs.createIndex({ strategy_id: 1, created_at: -1 })
db.backtest_runs.createIndex({ strategy_config_id: 1, created_at: -1 })
db.backtest_runs.createIndex({ status: 1, created_at: -1 })

db.backtest_trades.createIndex({ run_id: 1, entry_time: 1 })
db.backtest_orders.createIndex({ run_id: 1, timestamp: 1 })
db.backtest_signals.createIndex({ run_id: 1, timestamp: 1 })
db.backtest_equity.createIndex({ run_id: 1, timestamp: 1 })
```

---

## 13. Data integrity

A completed run must have:

```text
strategy_id
strategy_config_id
strategy_config_snapshot
dataset_version
symbols
start/end
base_timeframe = 1m
initial_capital
simulation config
```

No result should be marked `COMPLETED` if those inputs are missing or inconsistent.
