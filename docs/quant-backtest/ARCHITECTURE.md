# Quant Backtest Service — Technical Architecture v1

## 1. Purpose

`quant-backtest` is a Python service dedicated to quantitative research and historical backtesting.

The service is intentionally **not** a trading execution platform. Java owns business workflow and order execution through BPMN. Python owns market-data replay, strategy evaluation, ICT/Price Action logic, simulated execution and backtest analytics.

### In scope

- Multi-market architecture: crypto, forex, stocks, futures and other supported instruments.
- Canonical market data at 1-minute OHLCV resolution.
- Higher timeframes derived from the 1m stream.
- Event-driven, stateful Python strategies.
- Multi-timeframe strategies.
- Level-3 intrabar simulation using 1m data as the lowest available resolution.
- Strategy source code is selected by a stable `strategy_id`; strategy versioning is intentionally out of scope.
- Strategy behavior is controlled by a persisted `strategy_config` document in MongoDB.
- Reproducible backtest runs.
- Backtest metrics, trades, signals, equity and audit metadata.
- FastAPI API for Java and other callers.
- Asynchronous backtest execution via worker boundary.

### Out of scope for v1

- Live trading.
- Realtime signal generation.
- Exchange/broker order execution.
- Paper trading.
- Arbitrary user-uploaded Python strategy execution.
- Automated parameter optimization.
- AI strategy generation.
- Order-book / tick-level simulation.

---

## 2. Architectural principles

### 2.1 Strategy is the business logic

A strategy is a real Python class. It is stateful and event-driven. It should express trading logic such as:

- market structure
- swing detection
- BOS / CHOCH
- liquidity sweep
- FVG
- order block
- displacement
- session rules
- entry / exit rules
- position sizing

A strategy must not know about FastAPI, MongoDB, Java, BPMN or HTTP.

### 2.2 Backtest engine is infrastructure

NautilusTrader is used as the simulation kernel. Its types and APIs stay behind an infrastructure adapter.

Domain code must not import `nautilus_trader` directly unless that code is explicitly classified as an adapter/integration module.

### 2.3 MongoDB is the application data source

MongoDB is the system of record for 1m OHLCV data and persisted run metadata/results.

The backtest runtime should load data into an efficient in-memory / Arrow / Nautilus representation before replay. A strategy must never perform MongoDB queries inside `on_bar`.

### 2.4 1m is the canonical timeframe

A backtest uses 1m OHLCV as the canonical lowest resolution. Higher timeframes are derived deterministically from 1m data.

Even if MongoDB contains precomputed 5m/15m/1H bars, those bars are not the authoritative source for the v1 backtest path. This avoids different aggregation rules creating different MTF results.

### 2.5 Execution is outside the service

The Python service may simulate orders to calculate backtest results, but it never sends real orders.

Java/BPMN remains responsible for:

- approval
- business risk checks
- order creation
- exchange/broker integration
- retry
- reconciliation
- audit workflow

---

## 3. Logical architecture

```text
                         JAVA PLATFORM
                  Campaign / BPMN / Execution
                              |
                              | REST
                              v
+----------------------------------------------------------------+
|                    QUANT BACKTEST SERVICE                      |
|                                                                |
|  FastAPI / HTTP                                                |
|      |                                                         |
|      v                                                         |
|  Application Services                                          |
|      |                                                         |
|      +----------------------+-------------------+              |
|      |                      |                   |              |
|      v                      v                   v              |
|  Strategy Service      Backtest Service    Result Service     |
|      |                      |                   |              |
|      v                      v                   v              |
|  Strategy Registry     Backtest Runner      Mongo Repository   |
|                             |                                  |
|                             v                                  |
|                     Nautilus Adapter                            |
|                             |                                  |
|                             v                                  |
|                   Event-driven simulation                       |
|                             |                                  |
|                    +--------+---------+                         |
|                    |                  |                         |
|                    v                  v                         |
|              ICT / PA Domain      Portfolio / PnL              |
|                                                                |
+----------------------------------------------------------------+
                              |
                              v
                         MongoDB
```

---

## 4. Layering

```text
API
  -> Application
      -> Domain
          -> Infrastructure
```

### API layer

Responsibilities:

- HTTP routing.
- Request/response validation.
- Authentication hooks when added later.
- HTTP status mapping.
- No backtest logic.

Example modules:

```text
app/api/v1/backtests.py
app/api/v1/strategies.py
app/api/v1/health.py
```

### Application layer

Coordinates use cases:

```text
CreateBacktest
GetBacktest
GetBacktestTrades
ValidateStrategy
ListStrategies
```

It orchestrates repositories and infrastructure adapters but should not contain ICT algorithms.

### Domain layer

Pure trading concepts:

```text
Strategy
Signal
Trade
Market Structure
Liquidity
FVG
Order Block
Displacement
```

This layer should be highly unit-testable without FastAPI, MongoDB or a running Nautilus process.

### Infrastructure layer

External technology adapters:

```text
MongoDB
NautilusTrader
Job queue / worker
Object storage if introduced later
```

---

## 5. Backtest lifecycle

```text
POST /api/v1/backtests
        |
        v
Validate request
        |
        v
Create run metadata
        |
        v
Status = QUEUED
        |
        v
Enqueue worker job
        |
        v
Worker loads dataset
        |
        v
Normalize 1m bars
        |
        v
Build MTF event stream
        |
        v
Instantiate strategy
        |
        v
Replay historical events
        |
        +--> strategy state
        +--> ICT event detection
        +--> simulated orders
        +--> fills / PnL
        |
        v
Calculate metrics
        |
        v
Persist trades / equity / signals / metrics
        |
        v
Status = COMPLETED
```

On failure:

```text
RUNNING -> FAILED
```

with an error code, message and traceback reference in the run metadata.

---

## 6. Event-driven strategy model

Strategy execution is stateful.

Example sequence:

```text
10:00  swing state updated
10:05  sell-side liquidity swept
10:10  displacement detected
10:10  bullish CHOCH confirmed
10:15  FVG created
10:20  FVG retest
10:20  entry decision
```

The strategy must preserve relevant state across events rather than recompute the entire market from scratch on every candle.

Example interface:

```python
class Strategy:
    def on_start(self, context):
        pass

    def on_bar(self, bar):
        pass

    def on_stop(self):
        pass
```

The actual Nautilus strategy adapter may use Nautilus lifecycle signatures, but the domain/application contract should remain isolated from those implementation details.

---

## 7. Multi-timeframe architecture

The canonical event stream is 1m.

```text
1m OHLCV
   |
   +----> 5m aggregate
   |
   +----> 15m aggregate
   |
   +----> 1H aggregate
   |
   +----> 4H aggregate
   |
   +----> other configured timeframes
```

A strategy may consume several timeframes simultaneously.

Example:

```text
4H  -> directional bias
1H  -> market structure
15m -> liquidity/setup
5m  -> entry setup
1m  -> intrabar simulation / execution ordering
```

### Closed-bar rule

A higher-timeframe bar is emitted to strategy logic only when all of its constituent 1m bars have arrived.

For example, a 15m candle covering 10:00–10:14 must not be visible as a completed candle at 10:05.

This is mandatory to prevent look-ahead bias.

### Timezone

Canonical timestamps are UTC. Session-specific logic must explicitly define the relevant exchange/session timezone.

---

## 8. Level-3 intrabar model

The lowest available market resolution is 1m. Level-3 simulation therefore means that the engine can inspect the 1m path when evaluating orders associated with higher timeframe signals.

Example:

```text
15m setup
    |
    +--> 1m bars
            |
            +--> entry
            +--> stop loss
            +--> take profit
```

### Important limitation

1m OHLCV does not reveal the exact tick sequence inside a 1m candle.

If one 1m candle contains both a stop and target price, the exact first-touch order is unknowable from OHLCV alone.

Therefore the simulation must use a documented deterministic intrabar policy, for example:

```text
LOWER_TIMEFRAME_FIRST_AVAILABLE
OPEN_HIGH_LOW_CLOSE
OPEN_LOW_HIGH_CLOSE
CONSERVATIVE_STOP_FIRST
```

The selected policy becomes part of the strategy configuration and backtest reproducibility metadata.

The system must never claim tick-level execution accuracy from 1m OHLCV.

---

## 9. ICT / Price Action domain

ICT concepts are domain components, not FastAPI endpoints and not MongoDB queries.

Recommended decomposition:

```text
app/domain/ict/
├── swing.py
├── structure.py
├── bos.py
├── choch.py
├── liquidity.py
├── sweep.py
├── fvg.py
├── order_block.py
├── displacement.py
├── premium_discount.py
└── session.py
```

Example:

```python
class LiquidityDetector:
    def detect_sweep(self, context):
        ...
```

```python
class MarketStructure:
    def detect_bos(self, context):
        ...

    def detect_choch(self, context):
        ...
```

The strategy composes these domain services:

```text
Strategy
   |
   +--> StructureDetector
   +--> LiquidityDetector
   +--> FVGDetector
   +--> OrderBlockDetector
   +--> SessionFilter
```

This prevents a single 2,000–3,000 line strategy file from becoming the entire trading domain.

---

## 10. Strategy configuration

There is intentionally **no strategy-versioning model**.

A strategy is identified by a stable:

```text
strategy_id
```

Example:

```text
ict_liquidity_reversal
```

Its runtime parameters are stored in MongoDB as a strategy configuration:

```text
strategy_configs
```

A backtest request selects:

```text
strategy_id
+
strategy_config_id
```

Example:

```json
{
  "strategyId": "ict_liquidity_reversal",
  "strategyConfigId": "CFG-ICT-LR-001"
}
```

The configuration may contain:

```text
strategy parameters
market/timeframe requirements
risk assumptions
intrabar policy
fee model
slippage model
session settings
```

### Configuration snapshot

At run creation, the exact configuration used is copied into the backtest run.

This is not strategy versioning. It is an immutable input snapshot for reproducibility and audit.

---

## 11. Strategy registry

Strategy implementations are maintained in Git and registered explicitly.

Example:

```python
STRATEGY_REGISTRY = {
    "ict_liquidity_reversal": ICTLiquidityReversal,
    "ict_fvg_continuation": ICTFVGContinuation,
}
```

The API must never accept arbitrary Python source such as:

```text
python_code = "..."
```

This avoids remote-code-execution risk and keeps deployment behavior controlled.

---

## 12. Market data loading

Strategy code never accesses MongoDB directly.

```text
Strategy
   |
   v
MarketData API
   |
   v
In-memory cache / Arrow representation
   |
   v
MongoDB repository
```

The worker loads the requested range before starting the historical replay.

### Data validation

Before replay:

- timestamps must be UTC
- bars must be sorted
- no duplicate symbol/timestamp rows within a dataset
- OHLC invariants must hold
- volume must be non-negative
- requested range must be covered or gaps explicitly reported

A backtest should fail fast when required data is missing unless the run configuration explicitly permits gaps.

---

## 13. MongoDB responsibilities

MongoDB stores:

```text
market_bars_1m
market_datasets
strategies
strategy_configs
backtest_runs
backtest_metrics
backtest_trades
backtest_orders
backtest_signals
backtest_equity
```

Large result payloads should not be embedded into one MongoDB document. If equity curves or detailed artifacts become large, object storage can be introduced later while MongoDB retains metadata and URIs.

---

## 14. Backtest API

### Create

```http
POST /api/v1/backtests
```

Example:

```json
{
  "strategyId": "ict_liquidity_reversal",
  "strategyConfigId": "CFG-ICT-LR-001",
  "symbols": ["BTCUSDT"],
  "start": "2025-01-01T00:00:00Z",
  "end": "2025-12-31T23:59:00Z",
  "initialCapital": 100000
}
```

Response:

```json
{
  "runId": "BT-20260909-000001",
  "status": "QUEUED"
}
```

### Result

```http
GET /api/v1/backtests/{run_id}
```

### Trades

```http
GET /api/v1/backtests/{run_id}/trades
```

### Signals

```http
GET /api/v1/backtests/{run_id}/signals
```

### Equity

```http
GET /api/v1/backtests/{run_id}/equity
```

---

## 15. Asynchronous execution

Backtests must not run inside the FastAPI request worker.

```text
HTTP request
    |
    v
Create run
    |
    v
QUEUE
    |
    v
Quant worker
    |
    v
Nautilus backtest
```

The API returns `202 Accepted` semantics with a `run_id` while the worker runs independently.

Recommended initial architecture:

```text
FastAPI
Redis / queue
Worker
MongoDB
```

Kafka can replace or complement the queue later if the surrounding platform requires Kafka-native orchestration.

---

## 16. Run state machine

```text
QUEUED
  |
  v
RUNNING
  |
  +------> COMPLETED
  |
  +------> FAILED
  |
  +------> CANCELLED
```

Only the worker should transition a run after execution begins.

Each transition should include timestamps and a useful error code when applicable.

---

## 17. Reproducibility

Every completed run must identify its effective inputs.

```text
strategy_id
+
strategy_config_id
+
strategy_config_snapshot
+
dataset_version
+
symbols
+
start/end
+
base_timeframe = 1m
+
simulation configuration
+
backtest runtime metadata
```

The system should also record an application/build identifier so an operational deployment can be identified.

### Important consequence of no strategy versioning

The design deliberately does not model Python implementation versions as `strategy_version`.

If the implementation behind a stable `strategy_id` changes, old runs remain reproducible only when the deployed application artifact used for those runs is still identifiable and reproducible operationally.

This is an operational deployment concern, not a strategy-versioning entity.

---

## 18. Performance metrics

The first result set should include:

```text
Total Return
CAGR
Sharpe
Sortino
Maximum Drawdown
Win Rate
Profit Factor
Total Trades
Average Trade
Average Win
Average Loss
Exposure
```

Metrics must be calculated from persisted trade/equity information using a consistent definition documented in the implementation.

---

## 19. Testing strategy

### Unit tests

Test ICT domain components independently:

```text
swing
BOS
CHOCH
liquidity sweep
FVG
order block
displacement
session
```

### MTF tests

Test that:

```text
1m -> 5m
1m -> 15m
1m -> 1H
1m -> 4H
```

produce deterministic bars and only emit completed higher-timeframe candles.

### Look-ahead tests

Construct known data where the future close would change the apparent signal. Verify the signal does not appear before the higher-timeframe candle closes.

### Intrabar tests

Test:

```text
entry only
SL only
TP only
SL + TP in same 1m candle
entry + SL in same candle
entry + TP in same candle
```

for every supported deterministic intrabar policy.

### Integration tests

Test:

```text
MongoDB
   -> loader
   -> MTF
   -> strategy
   -> Nautilus adapter
   -> result repository
```

### Reproducibility test

Running the same dataset + config + simulation parameters twice should produce identical deterministic results.

---

## 20. Error handling

Use machine-readable error codes.

Examples:

```text
STRATEGY_NOT_FOUND
STRATEGY_CONFIG_NOT_FOUND
DATASET_NOT_FOUND
DATA_GAP_DETECTED
INVALID_MARKET_DATA
INVALID_DATE_RANGE
INVALID_TIMEFRAME
BACKTEST_ENGINE_ERROR
BACKTEST_CANCELLED
RESULT_PERSISTENCE_ERROR
```

The HTTP API should not expose raw internal tracebacks to callers. Store diagnostic details in logs/run metadata and return a stable error response.

---

## 21. Observability

Every backtest should have:

```text
run_id
correlation_id
strategy_id
strategy_config_id
```

These values should appear in structured logs.

Useful worker metrics:

```text
backtest_duration_seconds
bars_processed_total
trades_generated_total
backtest_failed_total
queue_wait_seconds
```

---

## 22. Deployment

Recommended containers:

```text
quant-api
quant-worker
```

```text
             +-------------+
Java ------> | quant-api   |
             +------+------+
                    |
                  queue
                    |
             +------v------+
             | quant-worker|
             +------+------+
                    |
             +------+-------+
             | MongoDB     |
             | Nautilus    |
             +-------------+
```

Workers should be horizontally scalable because independent backtests do not need to share process state.

---

## 23. Project structure

```text
quant-backtest/
├── app/
│   ├── main.py
│   ├── api/
│   │   └── v1/
│   │       ├── backtests.py
│   │       ├── strategies.py
│   │       └── health.py
│   ├── application/
│   │   ├── backtest_service.py
│   │   ├── strategy_service.py
│   │   └── result_service.py
│   ├── domain/
│   │   ├── strategy/
│   │   ├── ict/
│   │   └── models/
│   ├── infrastructure/
│   │   ├── nautilus/
│   │   ├── mongodb/
│   │   ├── market_data/
│   │   └── jobs/
│   └── config/
├── strategies/
├── tests/
│   ├── unit/
│   ├── ict/
│   ├── integration/
│   └── backtest/
├── scripts/
├── Dockerfile
├── docker-compose.yml
├── pyproject.toml
└── README.md
```

---

## 24. Deliberate non-goals

Do not gradually turn this service into a second Java platform.

Avoid adding:

```text
Campaign management
BPMN
Order approval
Exchange account management
Live order execution
User task UI
General-purpose workflow
```

Those belong to the existing Java system.

---

## 25. Implementation sequence

### Slice 1 — runnable skeleton

- FastAPI
- settings
- Mongo connection
- strategy registry
- health endpoint
- repository interfaces

### Slice 2 — market data

- Mongo 1m query
- normalization
- validation
- time ordering
- gap detection

### Slice 3 — MTF

- deterministic 1m → 5m/15m/1H/4H aggregation
- closed-bar semantics
- timezone/session handling
- no-look-ahead tests

### Slice 4 — Nautilus integration

- data adapter
- BacktestNode/BacktestEngine adapter
- simulated venue
- fill/fee/slippage configuration

### Slice 5 — strategy runtime

- lifecycle hooks
- event dispatch
- state persistence inside run context
- sample strategy

### Slice 6 — ICT domain

- swing
- structure
- liquidity
- sweep
- FVG
- OB
- displacement

### Slice 7 — results

- trades
- orders
- signals
- equity
- metrics
- Mongo persistence

### Slice 8 — worker

- async queue
- retries
- run status transitions
- failure handling

### Slice 9 — Java integration

- API contract hardening
- idempotency
- request correlation
- result polling or callback if needed

---

## 26. Key architectural decision

The central design decision is:

```text
MongoDB 1m
    ↓
Deterministic MTF event stream
    ↓
Event-driven Python Strategy
    ↓
NautilusTrader simulation
    ↓
Reproducible Backtest Result
```

Everything else should support this path and should not make the service responsible for live order execution.
