# Bug Audit Report - Enterprise Operations Console (AWS 3-Tier Architecture)

Repo: https://github.com/yashbaviskar15/3-tier-app
Deployed frontend: https://three-tier-app.vercel.app/
Audit scope: frontend (root console + four Vercel sub-apps), backend API (Vercel
serverless function and Node/Express app tier), data tier (Terraform RDS),
configuration and deployment (Vercel, GitHub Actions, Docker), security.

Every row below was reproduced or verified against the repository at commit
`38419c6` unless stated otherwise. The "Status" column is updated in Phase 4/5.

## Severity summary

| Severity | Count |
|---|---|
| Critical | 2 |
| High | 6 |
| Medium | 13 |
| Low | 13 |
| **Total** | **34** |

## Findings

| ID | Severity | Tier | Location | Symptom | Root cause | Planned fix | Status |
|---|---|---|---|---|---|---|---|
| BUG-001 | critical | Backend (App) | `src/app/index.js:233-271` | `POST /api/exec` runs any OS command supplied in the request body on the host and returns its stdout. Reachable from the public `src` Vercel app ("Live API Sandbox" button calls `/api/exec`). | `child_process.exec(trimmed, ...)` is called with unvalidated user input and no authentication, so the endpoint is a remote code execution sink. | Remove shell execution. Replace with an allow-listed, simulated command handler (same behaviour as the serverless `api/index.js`). | fixed |
| BUG-002 | critical | Backend (App) | `src/app/index.js:126-225` | `POST /api/connect-db` accepts an arbitrary `host`, `port`, `user`, `password` and `connectionString` and opens an outbound DB connection to the supplied target, with no auth or allowlist. | Endpoint is an unauthenticated SSRF / credential-relay primitive; `connectionString.split('@')` parsing also accepts caller-controlled hosts. | Validate input, reject non-allowlisted hosts, remove `connectionString` parsing, add a connection timeout. | fixed |
| BUG-003 | high | Frontend (Presentation) | `index.html:1232-1234, 1248-1250, 1269-1277, 1315` | When the backend is down the console still reports "Operational", logs fabricated success lines, and shows connected DB metrics. The user never sees an offline or error state. | Every `fetch` is wrapped in `try { ... } catch {}`; the catch blocks call `log(..., 'success')` with hardcoded values instead of surfacing the failure. | Introduce a typed API client and real error handling; add an offline/retry banner and never report success on failure. | fixed |
| BUG-004 | high | Backend (App) | `api/index.js:19-23`, `src/app/index.js:11-17` | Every response carries `Access-Control-Allow-Origin: *`, allowing any website to call the API. | CORS origin is hardcoded to `*` with no allowlist. | Make the allowed origins configurable via `ALLOWED_ORIGINS` (defaults to the Vercel domain + localhost) and echo only allowed origins. | fixed |
| BUG-005 | high | Backend (API) | `api/index.js:266-270` | Any unmatched route (including unknown `/api/*`) returns HTTP 200 with a JSON body, so clients and monitors cannot distinguish success from a missing endpoint. | A catch-all fallback returns `res.status(200)`. | Return HTTP 404 with the standard error envelope for unmatched routes. | fixed |
| BUG-006 | high | Data tier (Deployment) | `environments/prod/terraform.tfvars:7` | `terraform plan` fails for prod: the third data subnet `10.2.300.0/24` is not a valid CIDR (octet 300 > 255). | Typo in the CIDR list; also overlaps nothing else but is invalid. | Change to `10.2.120.0/24` (non-overlapping with app subnets 10.2.10/20/30). | fixed |
| BUG-007 | high | Security (Dependencies) | `src/app/package.json:9-15` | `npm audit` reports 5 vulnerabilities: 1 critical (proxy-addr), 1 high (body-parser), 3 moderate (aws-sdk, qs, uuid). `aws-sdk@2` is also end-of-support. | Old transitive versions pinned through `express@^4.19.2`, plus `aws-sdk` and `@supabase/supabase-js` that are declared but never imported anywhere in the code. | Remove the two unused dependencies and run `npm audit fix` to upgrade express transitive packages within the 4.x range. | fixed |
| BUG-008 | high | Frontend (Presentation) | `index.html:1216-1254` | Clicking "Sync Metrics" against a slow/hanging backend leaves the button spinner spinning forever (infinite spinner); no timeout. | `fetch` has no timeout / `AbortController`; `setSyncing(false)` only runs after both awaits resolve. | Add a request timeout and retry in the shared API client, and always clear loading state in a `finally`. | fixed |
| BUG-009 | medium | Backend (App) | `api/index.js:36-51`, `src/app/index.js:66-77` | `/api/health` always returns `tier3_database: HEALTHY` / `status: UP` with HTTP 200, even when the database is disconnected or emulated, so it is useless as a real health probe (the ALB target group uses this path). | Health handler returns static literal values instead of inspecting the actual DB state. | Derive health from the live (or emulated) DB state and set `status` / `tier3_database` accordingly. | fixed |
| BUG-010 | medium | Backend (App) | `api/index.js:91-263`, `src/app/index.js:126-271` | Request bodies are accepted without validation or size limits; malformed input yields confusing 200/500 responses. | No schema validation and `express.json()` is mounted without a `limit`. | Validate required fields and types, cap port/password/host length, and set a JSON body limit. | fixed |
| BUG-011 | medium | Backend (App) | `api/index.js` (all handlers), `src/app/index.js:95, 111, 151, 181, 220` | Error responses have inconsistent shapes and leak internal `err.message` (potentially stack/connection details) to clients. | Ad-hoc `{ error: err.message }` / `{ status: 'ERROR' }` responses; no shared error format. | Add a consistent `{ error: { code, message } }` envelope and map internal errors to safe messages. | fixed |
| BUG-012 | medium | Backend (App) | `api/index.js` (all), `src/app/index.js:7-17` | No security headers and no request rate limiting on a publicly reachable API. | Neither header middleware nor a limiter is present. | Add security-header middleware and a lightweight in-memory rate limiter on both backends (no new dependencies). | fixed |
| BUG-013 | medium | Backend (App) | `src/app/index.js:288-290` | A request to an unknown `/api/*` path returns the SPA `index.html` with HTTP 200 instead of a 404. | `app.get('*')` catch-all is registered after the API routes and also matches `/api/*`. | Add an explicit `/api/*` 404 JSON handler before the SPA fallback. | fixed |
| BUG-014 | medium | Backend (App) | `src/app/index.js:292-294` | The process has no SIGTERM/SIGINT handler and no `unhandledRejection`/`uncaughtException` handler, so redeploys leak DB connections and unexpected exceptions crash silently. | `app.listen` is called with no shutdown or process-level error handling. | Export the app, listen only when run directly, and add graceful shutdown plus process error logging. | fixed |
| BUG-015 | medium | Data tier (Backend) | `src/app/index.js:152-182, 190-199` | `/api/connect-db` creates a temporary pool, and on a failed connection test the pool is never closed, leaking connections across calls. | No `finally`/`catch` closes `tempPool` on the error path. | Close temporary pools in a `finally` block on failure. | fixed |
| BUG-016 | medium | Data tier (Terraform) | `modules/iam/main.tf:46-50` | The EC2 app role can read every secret in the account (`secretsmanager:GetSecretValue` on `*`), violating least privilege. | Secrets Manager statement hardcodes `resources = ["*"]`; the module has no input for the secret ARN. | Add a `secrets_manager_secret_arns` variable and pass `module.rds.secret_arn` from each environment. | fixed |
| BUG-017 | medium | Data tier (Terraform) | `modules/rds/main.tf:89` | RDS has `skip_final_snapshot = true` in every environment including production, so destroying the DB loses all data with no snapshot. | Hardcoded in the module with no variable override. | Add `skip_final_snapshot` variable (default true for dev/staging, false for prod). | fixed |
| BUG-018 | medium | Frontend (Presentation) | `index.html` (App root) | A single render error (e.g. unexpected API shape) blanks the whole page with no recovery UI. | No React error boundary wraps the app. | Add an ErrorBoundary component with a retry action. | fixed |
| BUG-019 | medium | Config | repo root; `package.json`, `src/app/package.json` | Environment variables (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`, `PORT`, `ALLOWED_ORIGINS`) are undocumented, and the root `package.json` declares `express`/`mysql2`/`pg` that `api/index.js` never imports. There is no committed root lockfile. | No `.env.example`; dependencies were added to the wrong manifest. | Add `.env.example` files, remove unused root deps, and commit lockfiles so `npm ci` works. | fixed |
| BUG-020 | medium | Frontend (Presentation) | `index.html:1062-1120, 903-952` | Form labels are not associated with their inputs (no `for`/`id`), status changes and the console are not announced (`aria-live` missing), and the Connect button has no busy/disabled state (double-submit possible). | Accessibility attributes and submit guards were never added. | Add `htmlFor`/`id`, `aria-live` regions, `aria-label`s and a disabled/busy state on submit. | fixed |
| BUG-021 | medium | Deployment (CI) | `.github/workflows/terraform.yml` | CI only formats/validates Terraform; the application and the four web apps have no lint/build/test gate, so app regressions are never caught. | Workflow predates the app; no app test setup exists. | Add an app job that runs install + lint (syntax) + tests on both Node manifests. | fixed |
| BUG-022 | low | Frontend (Presentation) | `index.html:955` | The topology diagram always shows the database node as connected (green) even if the DB status is not CONNECTED. | `const dbClass = dbStatus === 'CONNECTED' ? 'n-connected' : 'n-connected';` returns the same value in both branches. | Make the false branch render a disconnected style. | fixed |
| BUG-023 | low | Frontend (Presentation) | `index.html:1037-1043` | After switching the database, the configuration form keeps showing the previous host because local state is initialised once and never synced. | `useState(currentDb.host || ...)` only reads the prop on first mount. | Sync the form when the active DB changes. | fixed |
| BUG-024 | low | Frontend (Presentation) | `index.html:1042` | The password field is pre-filled with literal bullet characters (U+2022) which are submitted as the password if the user does not edit the field. | Initial state is the literal string `••••••••••••`. | Default the field to empty and use a placeholder instead. | fixed |
| BUG-025 | low | Frontend (Presentation) | `index.html:903-952, 1339` | The `region` prop is passed into `Header` but never rendered, so region information is dead code. | Unused prop. | Remove the unused prop (or render it); kept minimal by removing it. | fixed |
| BUG-026 | low | Data tier (Observability) | `modules/cloudwatch/main.tf:40-41, 108-110` | The ASG high-CPU alarm and the ASG dashboard widget never receive data and the alarm never fires. | `CPUUtilization` is queried in the `AWS/EC2` namespace but dimensioned by `AutoScalingGroupName`; ASG-level CPU is not published under `AWS/EC2` with that dimension. | Dimension the alarm/widget correctly (metric math over instance IDs) or remove the misleading ASG-scoped CPU metric. | fixed |
| BUG-027 | low | Data tier (Terraform) | `modules/rds/main.tf:110` | The DB credential secret is deleted immediately (no recovery window), so an accidental delete is unrecoverable. | `recovery_window_in_days = 0` hardcoded. | Make it configurable with a safe default (`7`). | fixed |
| BUG-028 | low | Data tier (Terraform) | `modules/alb/main.tf:9` | The ALB cannot have deletion protection enabled; an accidental `terraform destroy` takes the load balancer down in production. | `enable_deletion_protection = false` hardcoded with no variable. | Add an `enable_deletion_protection` variable (prod sets true). | fixed |
| BUG-029 | low | Data tier (Terraform) | `modules/s3/main.tf` | The access-logs bucket has no versioning, so logs can be overwritten/deleted with no recovery. | Only the static bucket has an `aws_s3_bucket_versioning` resource. | Add versioning to the logs bucket. | fixed |
| BUG-030 | low | Frontend (all apps) | `src/index.html:650`, `modules/index.html:815,820`, `environments/index.html:601`, `docs/SECURITY.md` | Emoji / decorative Unicode characters appear in UI labels and documentation, violating the "no emojis" rule. | U+2713 check mark used as a label prefix; U+2705 and U+26A0/U+FE0F used in the security matrix. | Remove the symbols and use plain words. | fixed |
| BUG-031 | low | Frontend (sub-app) | `src/index.html:584-603` | The "Live API Sandbox" shows fabricated success JSON with the correct-looking shape whenever the request fails, hiding real errors. | `catch (e)` returns hardcoded per-endpoint mock responses. | Surface the real error message (status + body) instead of mocks. | fixed |
| BUG-032 | low | Frontend (sub-app) | `modules/index.html:824-828` | `main.tf` / `variables.tf` / `outputs.tf` tabs look clickable but do nothing; they are `<div>`s with pointer styling and no handler. | Tabs were styled as controls but never wired to state. | Remove the non-functional tabs (only one code view is available). | fixed |
| BUG-033 | low | Frontend (sub-apps) | `src/index.html:649,679-688`, `modules/index.html:819`, `environments/index.html:600` | Buttons default to `type="submit"`; if ever placed in a form this submits unexpectedly. | Missing `type` attribute. | Add `type="button"`. | fixed |
| BUG-034 | low | Backend (App) | `api/index.js:42,62`, `src/app/index.js:72,281` | The API reports region `ap-south-1` while the Terraform stack deploys to `us-east-1`, so operational data is misleading. | Region hardcoded in source. | Read region from `AWS_REGION` (default `us-east-1`). | fixed |

## Notes and scope decisions

- No `.env.example` existed; secrets or credentials are not committed, but
  configuration inputs were previously undocumented (BUG-019).
- The project has no ESLint, TypeScript or bundler configuration. Adding a full
  ESLint/TS toolchain is out of scope for the existing stack, so `lint` is
  implemented as a zero-dependency syntax check (`node --check`) and `test`
  uses the Node built-in `node:test` runner. No new runtime dependency is added.
- Terraform cannot be executed in the audit sandbox (no `terraform` binary, no
  AWS credentials). Terraform changes are syntax-reviewed manually and are
  covered by the existing CI `terraform validate` job; this is listed as a
  manual step in the final summary.
- The database tier in the deployed Vercel app is emulated in memory
  (`api/index.js`) and the Express app falls back to an in-memory mock when no
  `DB_*` variables are present. There is therefore no persistent schema in this
  repository and no migration is required; the only data-tier structural change
  is the prod CIDR fix (BUG-006).
