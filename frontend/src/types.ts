// Shared types mirroring the backend Pydantic schemas.

export interface PermitRequest {
  name: string;
  type: string;
  parcel?: string;
  documentUrl?: string;
}

export interface SubmitResponse {
  status: string;
  correlationId: string;
  message: string;
}

export interface ExtractedPermit {
  applicantName?: string;
  serviceAddress?: string;
  parcelId?: string;
  serviceType?: string;
  signaturePresent: boolean;
}

export interface ComplianceResult {
  score: number;
  missing: string[];
  flags: string[];
  tokens: number;
}

export interface ProcessResult {
  permitId?: string;
  correlationId: string;
  extracted: ExtractedPermit;
  compliance: ComplianceResult;
  status: string;
  deadLettered: boolean;
  eventPublished: boolean;
}

export interface TraceResponse {
  correlationId: string;
  columns: string[];
  rows: (string | number)[][];
}

export interface HealthResponse {
  status: string;
  version: string;
  mode: string;
  useCaseProfile: string;
  env: string;
}
