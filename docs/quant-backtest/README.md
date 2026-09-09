# Quant Backtest Service

Python/FastAPI service for multi-market, event-driven quantitative backtesting.

## What this service does

```text
MongoDB 1m OHLCV
      ↓
1m canonical event stream
      ↓
MTF aggregation
      ↓
Python Strategy
      ↓
ICT / Price Action
      ↓
NautilusTrader simulation
      ↓
Trades / Equity / Metrics
      ↓
MongoDB
```

## What it does not do

- It does not place live orders.
- It does not connect to exchanges for trading.
- It does not own BPMN workflows.
- It does not run arbitrary user Python code.
- It does not optimize parameters in v1.
- It does not require tick/order-book data.

Java/BPMN remains the execution platform.

## Locked decisions

| Area | Decision |
|---|---|
| Markets | Multi-asset |
| Source data | MongoDB |
| Canonical resolution | 1m OHLCV |
| Higher timeframes | Derived from 1m |
| Strategy | Python event-driven/stateful class |
| MTF | First-class |
| Backtest fidelity | Level 3 intrabar |
| Tick/order book | Out of scope |
| Strategy source | Git-managed Python, selected by stable `strategy_id` |
| Strategy versioning | None; behavior is controlled by MongoDB strategy configuration |
| Reproducibility | Required |
| Live trading | Out of scope |
| Optimization | Out of scope for v1 |
| Execution | Java/BPMN |

## Run locally

```bash
python -m venv .venv
. .venv/bin/activate
pip install -e '.[dev]'
uvicorn app.main:app --reload
```

Health:

```bash
curl http://localhost:8000/api/v1/health
```

Or with Docker:

```bash
docker compose up --build
```

## API entry points

```text
POST /api/v1/backtests
GET  /api/v1/backtests/{run_id}
GET  /api/v1/backtests/{run_id}/trades
GET  /api/v1/backtests/{run_id}/signals
GET  /api/v1/backtests/{run_id}/equity
POST /api/v1/strategies/validate
GET  /api/v1/strategies
GET  /api/v1/strategies/configs/{config_id}
```

Backtests are asynchronous and return a `runId`.

## Strategy example

Strategies are Python code stored in Git.

```python
class MyStrategy(Strategy):
    def on_start(self):
        self.structure = ...

    def on_bar(self, bar):
        ...
```

The strategy does not know about FastAPI or MongoDB.

## Important backtest rule

1m OHLCV is the canonical base timeframe. Even when MongoDB contains 5m/15m/1H bars, v1 derives higher timeframes from 1m for deterministic MTF behavior.

For ambiguous TP/SL ordering inside one 1m OHLC candle, the backtest configuration must specify a deterministic intrabar policy. Tick-order accuracy is not claimed.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the detailed design and [`MONGO_SCHEMA.md`](MONGO_SCHEMA.md) for the data model.
