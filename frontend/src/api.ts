// API client. Calls the governed backend (via APIM in the deployed flow, via
// the Vite proxy locally).
import type {
  HealthResponse,
  PermitRequest,
  ProcessResult,
  SubmitResponse,
  TraceResponse,
} from './types';

const BASE = import.meta.env.VITE_API_BASE ?? '';

async function json<T>(res: Response): Promise<T> {
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}

export async function getHealth(): Promise<HealthResponse> {
  return json<HealthResponse>(await fetch(`${BASE}/api/health`));
}

export async function submitPermit(req: PermitRequest): Promise<SubmitResponse> {
  return json<SubmitResponse>(
    await fetch(`${BASE}/api/permits`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req),
    }),
  );
}

export async function processQueue(): Promise<ProcessResult[]> {
  return json<ProcessResult[]>(await fetch(`${BASE}/api/process`, { method: 'POST' }));
}

export async function getTrace(correlationId: string): Promise<TraceResponse> {
  return json<TraceResponse>(await fetch(`${BASE}/api/trace/${correlationId}`));
}
