# Bug Audit Report - Enterprise Operations Console (AWS 3-Tier Architecture)

Audit scope: frontend (5 static React/CDN portals), application tier (`api/index.js` Vercel serverless
function and `src/app/index.js` Express service), data tier (RDS Terraform module), configuration
(Dockerfiles, `vercel.json`, CI workflow), deployment and security.

Every entry has file + line evidence, a reproduction, a root cause and a planned fix.
Severity order: critical, high, medium, low.

Legend for Status: `fixed` | `wont-fix` | `needs-info`.

---

## Summary table (sorted by severity)

| ID | Severity | Tier | Location | Symptom | Root cause | Planned fix | Status |
|----|----------|------|----------|---------|------------|-------------|--------|
| B-01 | critical | Application | `src/app/index.js:233-271` | `/api/exec` runs any OS command supplied by the caller (remote code execution) | `child_process.exec(trimmed)` executes raw user input with no allowlist | Replace shell execution with a fixed command allowlist that only returns simulated output; never spawn a shell | fixed |
| B-02 | critical | Data/Config | `environments/dev/backend_override.tf`, `environments/staging/backend_override.tf`, `environments/prod/backend_override.tf` | `terraform init` fails: "Duplicate backend configuration" | A second `terraform { backend "local" }` block coexists with `backend.tf` in the same directory | Delete the temporary `backend_override.tf` files | fixed |
| B-03 | critical | Data/Config | `environments/prod/terraform.tfvars:7`, `environments/prod/variables.tf:40` | `terraform plan` fails: "invalid CIDR address: 10.2.300.0/24" | Octet `300` is not a valid IPv4 octet (max 255) | Change third data subnet to a valid /24 (`10.2.102.0/24`) in tfvars, variables default and the environments portal display | fixed |
| B-04 | high | Data/Config | `environments/*/providers.tf`, `environments/*/main.tf:82` | Provider resolution warning; relies on implicit `hashicorp/template` install | `data "template_file"` used but `template` provider not declared; data source is deprecated | Replace `data "template_file"` with the built-in `templatefile()` function | fixed |
| B-05 | high | Application | `api/index.js:19-23`, `src/app/index.js:11-17` | Any website can call the API from a browser (`Access-Control-Allow-Origin: *`) | Wildcard CORS on all endpoints | Restrict origin to an allowlist from `ALLOWED_ORIGINS` env, keep credentials off, handle preflight | fixed |
| B-06 | high | Application | `api/index.js:265-270` | Unknown `/api/*` paths return HTTP 200 with a generic body instead of 404 | Catch-all fallback always responds 200 | Return 404 `{error}` for unmatched API routes; keep a documented index for `/api` | fixed |
| B-07 | high | Frontend | `index.html:1232-1251, 1269-1288, 1315-1329`; `src/index.html:592-601` | Backend outages are hidden: the UI logs fake success and shows fabricated data | `catch` blocks substitute hardcoded "success" payloads | Surface real error/offline state; remove fabricated success fallbacks | fixed |
| B-08 | high | Frontend | `index.html:1264-1268` | Clicking "Connect Database Cluster" with a failing backend silently does nothing | Response status not checked when `r.ok` is false | Handle non-2xx with an error log + status state | fixed |
| B-09 | high | Data | `modules/iam/main.tf:43,49` | EC2 role can read every secret and every S3 object in the account | IAM statements use `resources = ["*"]` | Scope Secrets Manager to the RDS secret ARN and drop the S3 wildcard fallback | fixed |
| B-10 | high | Data | `src/scripts/user_data.sh.tpl:20-24` | Bootstrap can fail or mangle credentials when a secret contains spaces/specials | `echo $SECRET_JSON` is unquoted (word splitting/globbing) | Quote the variable and pipe into `jq` | fixed |
| B-11 | high | Application | `api/index.js:36-52`; `src/app/index.js:66-77` | `/api/health` always reports HEALTHY/UP even with no working database | Health payload is fully static | Derive status from the actual DB configuration/state | fixed |
| B-12 | high | Application | `src/app/index.js:292-294` | No graceful shutdown, no listen-error handling, unhandled async init | `app.listen` has no error handler/SIGTERM handler; `initDatabase()` is a floating promise | Add listen error handling, SIGTERM/SIGINT graceful shutdown, and a centralized error handler | fixed |
| B-13 | high | Frontend | `index.html` (all fetch calls), `src/index.html:584-603` | No request timeout; a hung backend leaves the UI stuck forever | Raw `fetch` with no timeout/abort | Add an API client wrapper with timeout + retry | fixed |
| B-14 | medium | Frontend | `index.html:955` | Database node is always shown green | `dbStatus === 'CONNECTED' ? 'n-connected' : 'n-connected'` - both branches identical | Return a distinct class for the disconnected/unknown state | fixed |
| B-15 | medium | Frontend | `index.html:1042` | Submitting the DB form untouched sends the literal string `••••••••••••` as the password | Password state is initialised to bullet characters instead of empty | Initialise to empty string, add a `placeholder` | fixed |
| B-16 | medium | Frontend | `index.html:1062-1121, 1178-1188`; other portals | Inputs/labels not programmatically associated; terminal has no `aria-live`; clickable div tabs not keyboard operable | Missing `id`/`htmlFor`, missing `aria-live`, divs with `onClick` only | Add `id`/`htmlFor`, `aria-live="polite"`, `role="button"`+`tabIndex`+`onKeyDown` | fixed |
| B-17 | medium | Frontend | `src/index.html:650`; `modules/index.html:815,820`; `environments/index.html:601`; `docs/SECURITY.md:9-32` | Emoji/symbol characters present in UI and docs | U+2713 check mark and U+2705/U+26A0 symbols used as decoration | Replace with plain ASCII text | fixed |
| B-18 | medium | Frontend | `environments/index.html:458` | Portal displays an invalid production CIDR (`10.2.300.0/24`) | Copied from the invalid tfvars | Correct to `10.2.102.0/24` | fixed |
| B-19 | medium | Frontend | `modules/index.html:824-828` | `variables.tf` / `outputs.tf` look like tabs but do nothing | Tabs are decorative divs with no handler | Render only the actual tab that exists, or drive content from state | fixed |
| B-20 | medium | Application | `src/app/index.js:94-112, 179-221` | Error responses leak internal error messages; response shapes are inconsistent | `err.message` returned to clients; ad-hoc JSON shapes | Wrap responses in a stable error envelope and stop leaking internals | fixed |
| B-21 | medium | Application | `api/index.js` (whole file) | No centralized error handling; any thrown error becomes a generic 500 without a consistent shape | Handler body has no outer try/catch or error middleware | Add an outer wrapper and a uniform `{error:{code,message}}` envelope | fixed |
| B-22 | medium | Frontend | `docs/index.html:819` | Markdown is injected with `dangerouslySetInnerHTML` and no sanitisation | `marked.parse()` output rendered raw | Disable raw HTML in the markdown renderer | fixed |
| B-23 | medium | Data | `modules/rds/main.tf:89` | Instance replacement destroys the database with no final snapshot | `skip_final_snapshot = true` hardcoded | Make it a variable (default false for prod) with a `final_snapshot_identifier` | fixed |
| B-24 | medium | Frontend | all portals `<head>` | CDN scripts loaded without Subresource Integrity | `unpkg` scripts have no `integrity` hash | Documented as accepted risk (pinned major version); see notes - tracked, not changed | needs-info |
| B-25 | medium | Config | repo root | No `.env.example`; required env vars undocumented | Missing reference file | Add `.env.example` listing every variable | fixed |
| B-26 | low | Application | `src/app/index.js:21-39` | MySQL pool config sets `ssl` nowhere; RDS requires TLS | No `ssl` option | Add SSL for managed MySQL/PostgreSQL connections | fixed |
| B-27 | low | Frontend | `index.html:901` | `API_BASE` can fall back to `http://localhost:8080` (mixed content) | Protocol heuristic default | Default to same-origin, only fall back to localhost for `file:` protocol | fixed |
| B-28 | low | Frontend | `index.html:903` | `Header` accepts `region` prop it never uses | Dead prop | Remove the unused prop | fixed |
| B-29 | low | Data | `modules/vpc/main.tf:31-32` | Public subnets auto-assign public IPs | `map_public_ip_on_launch = true` | Set to `false` (ALB does not need it) | fixed |
| B-30 | low | Data | `modules/cloudwatch/main.tf:126-131` | RequestCount shown with `stat = "Average"` | Count metric should use `Sum` | Change the dashboard metric to `SampleCount`/`Sum` for the count | fixed |
| B-31 | low | Data | `src/scripts/user_data.sh.tpl:14,48` | `|| true` masks `useradd` errors; `npm install --production` deprecated | Bad shell flags | Use `id ... \|\| useradd`; switch to `--omit=dev` | fixed |
| B-32 | low | Data | `modules/alb/main.tf:9` | ALB deletion protection disabled in all envs | Hardcoded `false` | Make it a variable, enable for prod | fixed |
| B-33 | low | Config | `.github/workflows/terraform.yml:61,89` | Checkov `soft_fail: true`; commented deploy job uses `ap-south-1` while TF uses `us-east-1` | Hardcoded mismatch | Documented; region corrected in the commented example | fixed |
| B-34 | low | Frontend | `docs/index.html:748-751` | Empty search yields a blank sidebar with no message | No empty state | Add a "No results" empty state | fixed |

---

## Detailed findings

### B-01 - Remote code execution via `/api/exec` (critical)

- File: `src/app/index.js:233-271`
- Evidence:
  ```
  const options = { timeout: 5000, cwd: path.join(__dirname) };
  execCmd(trimmed, options, (error, stdout, stderr) => { ... });
  ```
- Reproduction (`src/app` running on :8080):
  ```
  curl -s -X POST http://localhost:8080/api/exec \
    -H 'Content-Type: application/json' \
    -d '{"command":"id"}'
  ```
  Returns the output of the `id` command - arbitrary command execution as the app user.
- Root cause: user input is passed straight to `child_process.exec`, which invokes `/bin/sh -c`.
- Planned fix: remove shell execution entirely. Serve the same simulated outputs from an allowlist keyed on the
  trimmed command; return 400 for anything not in the list. No `child_process` import remains.

### B-02 - Duplicate Terraform backend block (critical)

- Files: `environments/{dev,staging,prod}/backend_override.tf:1-7` alongside `backend.tf`.
- Reproduction: `cd environments/dev && terraform init` -> `Error: Duplicate backend configuration`.
- Root cause: Terraform merges every `*.tf` in the directory; two `backend` blocks is invalid.
- Planned fix: delete the three `backend_override.tf` files (they were temporary local-state helpers).

### B-03 - Invalid production CIDR (critical)

- Files: `environments/prod/terraform.tfvars:7`, `environments/prod/variables.tf:40`,
  `environments/index.html:458`.
- Evidence: `private_data_subnet_cidrs = ["10.2.100.0/24", "10.2.200.0/24", "10.2.300.0/24"]`.
- Reproduction: `terraform validate` / `plan` -> `Error: invalid CIDR address: 10.2.300.0/24`.
- Root cause: octet `300` exceeds the maximum 255.
- Planned fix: use `10.2.102.0/24` in tfvars, the variable default and the portal display.

### B-04 - Deprecated `template_file` data source without declared provider (high)

- Files: `environments/{dev,staging,prod}/main.tf:82-99`, `environments/{dev,staging,prod}/providers.tf`.
- Symptom: provider resolution warning; depends on implicit install of `hashicorp/template`.
- Root cause: `data "template_file"` is deprecated and its provider is not pinned.
- Planned fix: replace with `templatefile(...)` (core Terraform, no provider needed).

### B-05 - Wildcard CORS (high)

- Files: `api/index.js:19-23`, `src/app/index.js:11-17`.
- Reproduction: `curl -i https://three-tier-app.vercel.app/api/health -H 'Origin: https://evil.example'`
  -> `access-control-allow-origin: *`.
- Root cause: header hardcoded to `*`.
- Planned fix: read `ALLOWED_ORIGINS` (comma separated) or default to the app's own origin / known
  deployments; echo the origin only when allow-listed; keep preflight handling.

### B-06 - Unknown API routes return 200 (high)

- File: `api/index.js:265-270`.
- Reproduction: `curl -i .../api/does-not-exist` -> `HTTP 200`.
- Root cause: catch-all fallback.
- Planned fix: return `404` with the standard error envelope for unmatched routes; keep an index only for `/api`.

### B-07 / B-08 - Fabricated success responses hide outages (high)

- Files: `index.html:1232-1251, 1269-1288, 1315-1329`; `src/index.html:592-601`.
- Symptom: when the API is unreachable, the console logs "synchronized ... (Emulated Cloud Mesh Active)"
  and keeps showing invention data; the DB form swallows the failure.
- Root cause: `catch` blocks and `!r.ok` paths substitute hardcoded payloads.
- Planned fix: introduce a single typed API client with timeout+retry; on failure show an explicit
  offline/error banner and a "Retry" action; never write fabricated telemetry into state.

### B-09 - IAM wildcard resources (high)

- File: `modules/iam/main.tf:43,49`.
- Evidence: `resources = ["*"]` for S3 fallback and Secrets Manager.
- Root cause: convenience wildcards.
- Planned fix: pass `secrets_manager_secret_arns` into the module, scope the statement; make the S3
  statement conditional so an empty list grants nothing.

### B-10 - Unquoted secret expansion in bootstrap (high)

- File: `src/scripts/user_data.sh.tpl:20-24`.
- Evidence: `export DB_HOST=$(echo $SECRET_JSON | jq -r .host)`.
- Root cause: unquoted variable -> word splitting/globbing.
- Planned fix: `echo "$SECRET_JSON" | jq -r ...`.

### B-11 - Static health endpoint (high)

- Files: `api/index.js:36-52`, `src/app/index.js:66-77`.
- Planned fix: report dependency state derived from configuration (database configured and reachable ->
  HEALTHY, otherwise DEGRADED), keeping existing field names.

### B-12 - No graceful shutdown / listen error handling (high)

- File: `src/app/index.js:292-294`.
- Planned fix: capture the server handle, handle `error`, add SIGTERM/SIGINT shutdown that closes the
  HTTP server and the DB pools; add a final Express error-handling middleware.

### B-13 - No frontend timeout/retry (high)

- Files: `index.html`, `src/index.html` fetch calls.
- Planned fix: `createApiClient({ baseUrl, timeoutMs, retries })` using `AbortController`, exponential
  backoff for idempotent GETs, and a typed envelope.

### B-14 - Dead ternary on the topology map (medium)

- File: `index.html:955`. Fix: map `CONNECTED`/`DEGRADED`/`UNKNOWN` to distinct classes.

### B-15 - Password field pre-filled with bullet characters (medium)

- File: `index.html:1042`. Fix: empty default + `placeholder="••••••••••••"` (placeholder only, not a value).
  Note: the placeholder is plain-text masking, not an emoji.

### B-16 - Accessibility gaps (medium)

- File: `index.html:1062-1121, 1178-1188` and the other portals.
- Fix: add `id` + `htmlFor`, `aria-live="polite"` on the terminal/status regions, and make clickable div
  tabs keyboard operable (`role="button"`, `tabIndex={0}`, `onKeyDown` for Enter/Space).

### B-17 - Emoji/symbol usage (medium)

- Files: `src/index.html:650`, `modules/index.html:815,820`, `environments/index.html:601`,
  `docs/SECURITY.md:9-32`.
- Fix: replace `✓`/`✅`/`⚠️` with plain ASCII.

### B-18 - Invalid CIDR shown in the environments portal (medium)

- File: `environments/index.html:458`. Fix: `10.2.102.0/24`.

### B-19 - Decorative dead tabs (medium)

- File: `modules/index.html:824-828`. Fix: remove the non-functional tabs (only `main.tf` content exists).

### B-20 - Leaky, inconsistent error responses (medium)

- File: `src/app/index.js:94-112,179-221`.
- Fix: central error middleware returning `{ error: { code, message } }` with generic messages, real
  messages logged server-side only.

### B-21 - No centralized error handling in the serverless API (medium)

- File: `api/index.js`. Fix: wrap the handler and add a uniform error envelope + 404.

### B-22 - `dangerouslySetInnerHTML` markdown (medium)

- File: `docs/index.html:819`. Fix: configure `marked` so raw HTML is escaped.

### B-23 - `skip_final_snapshot = true` (medium)

- File: `modules/rds/main.tf:89`. Fix: variable-driven, snapshot enabled by default in prod.

### B-24 - Missing CDN SRI (medium, needs-info)

- All portals load `react`, `react-dom`, `@babel/standalone` from `unpkg` without `integrity`.
- Why not fixed now: SRI hashes must match the exact bytes served and must be regenerated on every
  dependency bump; an incorrect hash bricks the page. Tracked as a follow-up hardening task.

### B-25 - No `.env.example` (medium)

- Fix: add `.env.example` documenting every variable used by the app + serverless function.

### B-26 - No TLS for managed databases (low)

- File: `src/app/index.js:29-39`. Fix: add `ssl` options for MySQL/PostgreSQL.

### B-27 to B-34

Smaller items as described in the table: `API_BASE` fallback, unused `Header` prop, `map_public_ip_on_launch`,
dashboard `RequestCount` statistic, user-data shell flags, ALB deletion protection, CI region/soft-fail,
and the docs search empty state.

---

## Not-a-bug (investigated, no change)

- `src/vercel.json:4` rewrite `"/app/index.js"`: correct when the Vercel project root is `src/`
  (maps to `src/app/index.js`). Left as-is.
- `modules/cloudwatch/main.tf:36-53` high-CPU alarm `AWS/EC2` + `AutoScalingGroupName` dimension is a
  supported combination, so it was not changed.
- All `vercel.json` SPA rewrites already cover refresh/deep-link routing; no missing rewrite found.

---

## Manual steps required after merge

1. Set the environment variables listed in `.env.example` in Vercel (Production) and on the backend host.
2. Run `terraform init` in `environments/{dev,staging,prod}` after removing `backend_override.tf`.
3. `environments/prod/terraform.tfvars` third data subnet CIDR changed - review before applying to a live VPC.
