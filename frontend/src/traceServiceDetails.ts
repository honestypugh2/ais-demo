export interface TraceServiceDetail {
  service: string;
  what: string;
  how: string;
  why: string;
  currentFunction: string;
}

export function getTraceServiceDetail(operation: string): TraceServiceDetail {
  const name = operation.toLowerCase();

  if (name === 'post /permits') {
    return {
      service: 'Azure API Management',
      what: 'A managed API gateway for publishing, securing, observing, and governing APIs.',
      how: 'It is the permit portal\'s single front door and applies authentication, rate limits, subscription controls, and correlation IDs.',
      why: 'Consumers get one stable contract while backend services and policies can evolve independently.',
      currentFunction: 'Accept the permit request, enforce gateway policy, assign the correlation ID, and return HTTP 202.',
    };
  }

  if (name.endsWith('/permits-in/messages')) {
    return {
      service: 'Azure Service Bus (enqueue from API Management)',
      what: 'A durable enterprise message broker with retries, dead-lettering, and duplicate detection.',
      how: 'API Management writes the permit to the permits-in queue with its managed identity, using the parcel as the message ID.',
      why: 'HTTP 202 is returned only after Service Bus confirms the message (201), so accepted work is never lost.',
      currentFunction: 'Durably accept the permit; a resubmitted parcel inside the detection window is dropped as a duplicate.',
    };
  }

  if (name === 'send permits-in') {
    return {
      service: 'Azure Logic Apps',
      what: 'A managed workflow service for coordinating integration steps with low-code connectors and control flow.',
      how: 'The intake workflow validates and enriches the accepted request before sending it to the permits-in queue.',
      why: 'Business orchestration remains visible and changeable without coupling it to the permit-processing code.',
      currentFunction: 'Route the accepted permit into durable asynchronous processing.',
    };
  }

  if (name === 'servicebustrigger' || name === 'servicebusprocessor.processmessage') {
    return {
      service: 'Azure Service Bus and Azure Functions',
      what: 'Service Bus is a durable enterprise message broker; Functions provides event-driven serverless compute.',
      how: 'Service Bus holds permit messages until the permit-processor Function receives and processes them.',
      why: 'The queue absorbs traffic spikes, supports retries and dead-lettering, and decouples intake from processing.',
      currentFunction: 'Deliver this queued permit and start the processing function.',
    };
  }

  if (name.includes('analyze prebuilt-layout')) {
    return {
      service: 'Azure Document Intelligence',
      what: 'An AI service that extracts text, structure, and fields from documents.',
      how: 'The processor uses the prebuilt layout model with the key-value pairs add-on to extract applicant and permit fields from the submitted packet.',
      why: 'It replaces brittle document parsing with a managed model that supports varied layouts and formats.',
      currentFunction: 'Extract the structured permit fields used by validation and downstream systems.',
    };
  }

  if (name.includes('score compliance') || name.endsWith('/openai/v1/responses')) {
    return {
      service: 'API Management AI gateway and Microsoft Foundry',
      what: 'A Foundry model (gpt-5.4-mini) served through the Azure OpenAI v1 API; the API Management AI gateway adds content safety, token limits, metrics, and managed-identity access.',
      how: 'The Function sends extracted fields through APIM to the Responses API, which returns a structured compliance review.',
      why: 'Model access stays governed and observable, with content safety, token controls, and per-team usage attribution in one gateway.',
      currentFunction: 'Return an advisory compliance score, missing fields, and flags that route the permit to a human review state.',
    };
  }

  if (name.includes('contentsafety')) {
    return {
      service: 'Azure AI Content Safety (via the AI gateway)',
      what: 'A service that detects harmful content and prompt-injection attempts (Prompt Shields).',
      how: 'The llm-content-safety policy checks every prompt before it reaches the model.',
      why: 'Unsafe or adversarial prompts are blocked at the gateway with HTTP 403, before any model tokens are spent.',
      currentFunction: 'Screen this scoring request; it passed, so the gateway forwarded it to the model.',
    };
  }

  if (name === 'create permit record') {
    return {
      service: 'Case-system adapter (CRM)',
      what: 'The system-of-record integration that stores the validated permit for case management.',
      how: 'The processor writes the extracted fields, compliance outcome, and correlation ID through the adapter: an in-memory stub by default, or the HTTP endpoint set in CRM_BASE.',
      why: 'Operational teams need a durable business record after automated intake and validation complete.',
      currentFunction: 'Create the permit record and return the permit ID shown in the processing result.',
    };
  }

  if (
    name.includes('publish permitcreated') ||
    name.endsWith('/api/events') ||
    name.startsWith('eventgridpublisherclient')
  ) {
    return {
      service: 'Azure Event Grid',
      what: 'A managed publish-subscribe event routing service for reactive, loosely coupled systems.',
      how: 'The processor publishes PermitCreated after the CRM record is successfully created.',
      why: 'Notification, analytics, and future subscribers can react independently without changing the processor.',
      currentFunction: 'Fan out the completed permit event to interested subscribers.',
    };
  }

  return {
    service: 'Application dependency',
    what: 'A dependency captured as part of the correlated application trace.',
    how: 'The operation participates in this permit request using the same correlation ID.',
    why: 'Tracing dependencies makes latency, status, and ownership visible across the workflow.',
    currentFunction: operation,
  };
}