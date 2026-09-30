import { useEffect, useState } from 'react';
import { CloseIcon, InfoIcon } from './icons';
import { getHealth, getTrace, processQueue, submitPermit } from './api';
import { getTraceServiceDetail } from './traceServiceDetails';
import type { HealthResponse, ProcessResult, TraceResponse } from './types';

export default function App() {
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [name, setName] = useState('Jordan Lee');
  const [type, setType] = useState('Building');
  const [parcel, setParcel] = useState('AIS-2026-00417');
  const [correlationId, setCorrelationId] = useState<string>('');
  const [results, setResults] = useState<ProcessResult[]>([]);
  const [trace, setTrace] = useState<TraceResponse | null>(null);
  const [selectedTraceRow, setSelectedTraceRow] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    getHealth().then(setHealth).catch((e) => setError(String(e)));
  }, []);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    setTrace(null);
    setSelectedTraceRow(null);
    setResults([]);
    try {
      const submit = await submitPermit({ name, type, parcel });
      setCorrelationId(submit.correlationId);
      const processed = await processQueue();
      setResults(processed);
      const t = await getTrace(submit.correlationId);
      setTrace(t);
    } catch (err) {
      setError(String(err));
    } finally {
      setBusy(false);
    }
  }

  const selectedRow = selectedTraceRow === null ? null : trace?.rows[selectedTraceRow];
  const operationIndex = trace?.columns.indexOf('name') ?? -1;
  const resultIndex = trace?.columns.indexOf('resultCode') ?? -1;
  const durationIndex = trace?.columns.indexOf('duration') ?? -1;
  const selectedOperation =
    selectedRow && operationIndex >= 0 ? String(selectedRow[operationIndex]) : '';
  const selectedDetail = selectedOperation ? getTraceServiceDetail(selectedOperation) : null;

  return (
    <div className="page">
      <header className="hero">
        <p className="eyebrow">Azure Integration Services · Demo</p>
        <h1>Permit Intake Portal</h1>
        <p className="sub">
          Governed submit → messaging → AI validation → CRM → events → one traced journey.
        </p>
        {health && (
          <div className="status">
            <span className={`pill ${health.mode}`}>{health.mode} mode</span>
            <span className="pill">v{health.version}</span>
            <span className="pill">{health.useCaseProfile}</span>
          </div>
        )}
      </header>

      <main className="grid">
        <section className="card">
          <h2>Submit a permit</h2>
          <form onSubmit={onSubmit}>
            <label>
              Applicant name
              <input value={name} onChange={(e) => setName(e.target.value)} required />
            </label>
            <label>
              Permit type
              <input value={type} onChange={(e) => setType(e.target.value)} required />
            </label>
            <label>
              Parcel / reference
              <input value={parcel} onChange={(e) => setParcel(e.target.value)} />
            </label>
            <button type="submit" disabled={busy}>
              {busy ? 'Processing…' : 'Submit permit'}
            </button>
          </form>
          {correlationId && (
            <p className="cid">
              Correlation ID: <code>{correlationId}</code>
            </p>
          )}
          {error && <p className="error">{error}</p>}
        </section>

        <section className="card">
          <h2>Processing result</h2>
          {results.length === 0 && <p className="muted">Submit a permit to see the result.</p>}
          {results.map((r) => (
            <div key={r.permitId} className="result">
              <div className="row">
                <span>Permit</span>
                <code>{r.permitId}</code>
              </div>
              <div className="row">
                <span>Status</span>
                <span className={`badge ${r.status}`}>{r.status}</span>
              </div>
              <div className="row">
                <span>Compliance</span>
                <strong>{r.compliance.score}/100</strong>
              </div>
              {r.compliance.flags.length > 0 && (
                <ul className="flags">
                  {r.compliance.flags.map((f) => (
                    <li key={f}>{f}</li>
                  ))}
                </ul>
              )}
              <div className="row">
                <span>Event published</span>
                <span>{r.eventPublished ? '✓' : '—'}</span>
              </div>
            </div>
          ))}
        </section>

        <section className="card wide">
          <h2>End-to-end trace</h2>
          {!trace && <p className="muted">The correlated journey appears here after submit.</p>}
          {trace && (
            <>
              <div className="trace-table-wrap">
                <table>
                  <thead>
                    <tr>
                      {trace.columns.map((c) => (
                        <th key={c}>{c}</th>
                      ))}
                      <th className="details-column">Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {trace.rows.map((row, i) => (
                      <tr
                        key={i}
                        className={selectedTraceRow === i ? 'selected-trace-row' : undefined}
                      >
                        {row.map((cell, j) => (
                          <td key={j}>{String(cell)}</td>
                        ))}
                        <td className="details-cell">
                          <button
                            type="button"
                            className="trace-detail-button"
                            aria-label={`Explain ${String(row[operationIndex] ?? 'trace operation')}`}
                            aria-expanded={selectedTraceRow === i}
                            title="Explain this service"
                            onClick={() => setSelectedTraceRow(selectedTraceRow === i ? null : i)}
                          >
                            <InfoIcon size={17} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {selectedDetail && selectedRow && (
                <section className="trace-explanation" aria-live="polite">
                  <div className="trace-explanation-heading">
                    <div>
                      <p className="trace-kicker">Selected service</p>
                      <h3>{selectedDetail.service}</h3>
                    </div>
                    <button
                      type="button"
                      className="trace-detail-button"
                      aria-label="Close service explanation"
                      title="Close explanation"
                      onClick={() => setSelectedTraceRow(null)}
                    >
                      <CloseIcon size={17} />
                    </button>
                  </div>
                  <dl className="trace-explanation-grid">
                    <div>
                      <dt>What it is</dt>
                      <dd>{selectedDetail.what}</dd>
                    </div>
                    <div>
                      <dt>How it is used</dt>
                      <dd>{selectedDetail.how}</dd>
                    </div>
                    <div>
                      <dt>Why it is used</dt>
                      <dd>{selectedDetail.why}</dd>
                    </div>
                    <div>
                      <dt>Current function</dt>
                      <dd>{selectedDetail.currentFunction}</dd>
                    </div>
                  </dl>
                  <p className="trace-observation">
                    Observed in this trace: result {String(selectedRow[resultIndex] ?? 'n/a')} in{' '}
                    {String(selectedRow[durationIndex] ?? 'n/a')} ms.
                  </p>
                </section>
              )}
            </>
          )}
        </section>
      </main>

      <footer>
        AIS Demo · synthetic data · development use only — apply Well-Architected hardening before
        production.
      </footer>
    </div>
  );
}
