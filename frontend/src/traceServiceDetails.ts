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

  if (name === 'send permits-in') {
    return {
      service: 'Azure Logic Apps',
      what: 'A managed workflow service for coordinating integration steps with low-code connectors and control flow.',
      how: 'The intake workflow validates and enriches the accepted request before sending it to the permits-in queue.',
      why: 'Business orchestration remains visible and changeable without coupling it to the permit-processing code.',
      currentFunction: 'Route the accepted permit into durable asynchronous processing.',
    };
  }

  if (name === 'servicebustrigger') {
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
      service: 'Azure AI Document Intelligence',
      what: 'An AI service that extracts text, structure, and fields from documents.',
      how: 'The processor uses the prebuilt layout model to extract applicant and permit fields from the submitted packet.',
      why: 'It replaces brittle document parsing with a managed model that supports varied layouts and formats.',
      currentFunction: 'Extract the structured permit fields used by validation and downstream systems.',
    };
  }

  if (name.includes('score compliance')) {
    return {
      service: 'API Management AI gateway and Azure OpenAI',
      what: 'Azure OpenAI provides the model; the API Management AI gateway adds centralized security, limits, metrics, and policy.',
      how: 'The Function sends extracted fields through APIM to the model for a permit compliance score.',
      why: 'Model access stays governed and observable, with token controls and per-team usage attribution in one gateway.',
      currentFunction: 'Evaluate the extracted permit and return its compliance score, missing fields, and flags.',
    };
  }

  if (name === 'create permit record') {
    return {
      service: 'CRM integration',
      what: 'The system-of-record integration that stores the validated permit for case management.',
      how: 'The processor writes the extracted fields, compliance outcome, and correlation ID to the CRM adapter.',
      why: 'Operational teams need a durable business record after automated intake and validation complete.',
      currentFunction: 'Create the permit record and return the permit ID shown in the processing result.',
    };
  }

  if (name.includes('publish permitcreated')) {
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