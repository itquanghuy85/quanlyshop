# AI Security Risk Audit - Data Read and Token Exposure

Date: 2026-05-25
Scope: `lib/services/ai_chat_service.dart`, `functions/index.js`, AI cloud-call flow (`chatAssistant`, `createRepairOrderAI`)

## 1. Executive Summary

- Current design already keeps DeepSeek API key on server side via Google Secret Manager.
- Main residual risk is not API key leakage from mobile client, but over-sharing business context to AI and sensitive logging in Cloud Functions.
- Overall risk level: Medium.

## 2. Verified Current Protections

1. API key is server-side secret (`DEEPSEEK_API_KEY`) and not embedded in Flutter app.
2. AI endpoints require authentication (`request.auth`).
3. Basic rate limit exists:
- `createRepairOrderAI`: 30 req/min/user.
- `chatAssistant`: 20 req/min/user.
4. Input size is capped (question substring 500 chars) and history is capped (10 turns).

## 3. Risk Findings

### R1 - Over-broad data context sent to AI

- Evidence:
- `chatAssistant` receives `stats` and `history` from client.
- `statsContext` can include debt summaries and repair summaries with customer-facing details.
- Impact:
- Sensitive business data can be forwarded to third-party model provider unnecessarily.
- Leakage surface grows with every broad context expansion.
- Severity: High.

### R2 - Prompt/answer logging includes user content

- Evidence:
- Server logs currently record question preview and answer preview (`console.log` with string slices).
- Impact:
- PII or business-sensitive content may persist in logs beyond intended retention.
- Severity: High.

### R3 - Client-trusted stats/history integrity risk

- Evidence:
- `chatAssistant` accepts `stats` from client payload instead of rebuilding from server DB.
- Impact:
- User with modified client may inject fabricated context into AI flow.
- This is an integrity risk (not direct data breach), but can distort decisions and audit traces.
- Severity: Medium.

### R4 - Data minimization not enforced by intent class

- Evidence:
- Current flow sends generic stats package even for narrow intents.
- Impact:
- Token usage and data exposure increase, especially for simple navigation questions.
- Severity: Medium.

### R5 - No explicit secret-rotation/incident runbook in docs

- Evidence:
- Secret usage exists, but no documented operational runbook for key rotation and compromise response.
- Impact:
- Longer recovery window if key leak suspected.
- Severity: Medium.

## 4. Token Risk Assessment

Token risks evaluated in two dimensions:

1. Credential token leakage (API key/token):
- API key is server-side only. Current risk Low-Medium, mostly operational (logs/deployment errors) rather than client extraction.

2. AI usage token abuse/cost overrun:
- Rate limiting exists but is per-user and minute-window only.
- Missing global shop-level quota and anomaly alerts.
- Current risk Medium.

## 5. Recommended Mitigations (Priority)

## P0 (Implement first)

1. Remove raw question/answer content from logs.
- Keep only hashed request ID, uid, intent, latency, token count.

2. Enforce context minimization by intent.
- Navigation intents: send no stats.
- Finance summary intent: send aggregate only, no customer-level lines.

3. Strip PII before cloud AI call where not required.
- Mask phone numbers and identifiable names in history snippets.

## P1

1. Move context assembly to server when feasible.
- Ignore or strictly validate client `stats`.

2. Add dual-throttle strategy.
- Per-user limit + per-shop/day budget.

3. Add secret-rotation SOP.
- Monthly rotation, emergency revoke-and-redeploy process.

## P2

1. Add AI safety telemetry dashboard.
- Error ratio, timeout ratio, token usage, prompt volume.

2. Add retention policy for `_ai_rate_limit*` and AI diagnostic logs.

## 6. Proposed Guardrail Checklist

- [ ] Never log raw prompt/answer in production.
- [ ] Mask phone/name before sending to model unless strictly needed.
- [ ] Keep history <= 6 turns for chat assistant.
- [ ] Limit model context to least-privilege fields.
- [ ] Separate intents requiring detailed context from intents that do not.
- [ ] Set alert on request spikes and cost spikes.
- [ ] Document key rotation and incident response steps.

## 7. Implementation Notes for This Audit

- This audit is documentation-only and does not alter runtime logic.
- Next implementation step should be a dedicated hardening task in Cloud Functions:
- Redacted logging.
- PII masking utility.
- Intent-based context builder.