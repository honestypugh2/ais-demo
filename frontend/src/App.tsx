import { useEffect, useState } from 'react';
import { getHealth, getTrace, processQueue, submitPermit } from './api';
import type { HealthResponse, ProcessResult, TraceResponse } from './types';

export default function App() {
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [name, setName] = useState('Jordan Lee');
  const [type, setType] = useState('Building');
  const [parcel, setParcel] = useState('AIS-2026-00417');
  const [correlationId, setCorrelationId] = useState<string>('');
  const [results, setResults] = useState<ProcessResult[]>([]);
  const [trace, setTrace] = useState<TraceResponse | null>(null);
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
            <table>
              <thead>
                <tr>
                  {trace.columns.map((c) => (
                    <th key={c}>{c}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {trace.rows.map((row, i) => (
                  <tr key={i}>
                    {row.map((cell, j) => (
                      <td key={j}>{String(cell)}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
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
