/**
 * Shared API client for the Enterprise Operations Console.
 *
 * Provides a small, typed wrapper around fetch with:
 *   - request timeouts (AbortController)
 *   - bounded retries with backoff for idempotent requests and transient errors
 *   - a single normalized error type (ApiError) so callers never have to guess
 *
 * It is a plain UMD module so the browser can load it through a script tag
 * (window.ApiClient) and Node can require it for unit tests. No dependencies.
 *
 * @typedef {'TIMEOUT'|'NETWORK_ERROR'|'HTTP_400'|'HTTP_404'|'HTTP_500'|string} ApiErrorCode
 *
 * @typedef {Object} ApiErrorShape
 * @property {string} code    machine readable error code
 * @property {string} message human readable error message
 * @property {number} status  HTTP status (0 when the request never reached the server)
 * @property {boolean} retryable
 * @property {*} [details]
 *
 * @typedef {Object} HealthResponse
 * @property {string} status
 * @property {string} tier3_database
 *
 * @typedef {Object} InfoResponse
 * @property {string} [hostname]
 * @property {string} [platform]
 * @property {string} [region]
 *
 * @typedef {Object} DbStatusResponse
 * @property {string} status
 * @property {string} [database]
 * @property {string} [host]
 * @property {string} [engine]
 *
 * @typedef {Object} ConnectDbRequest
 * @property {string} host
 * @property {string|number} [port]
 * @property {string} [user]
 * @property {string} [password]
 * @property {string} [database]
 * @property {string} [engine]
 *
 * @typedef {Object} ExecResponse
 * @property {string} [output]
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.ApiClient = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /**
   * Normalized error thrown by ApiClient for every failure mode.
   */
  class ApiError extends Error {
    /**
     * @param {string} message
     * @param {ApiErrorShape} [shape]
     */
    constructor(message, shape) {
      super(message);
      const s = shape || {};
      this.name = 'ApiError';
      this.code = s.code || 'API_ERROR';
      this.status = typeof s.status === 'number' ? s.status : 0;
      this.retryable = !!s.retryable;
      this.details = s.details === undefined ? null : s.details;
    }
  }

  /** @param {number} ms */
  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  /**
   * @param {unknown} value
   * @returns {value is string}
   */
  function isNonEmptyString(value) {
    return typeof value === 'string' && value.trim().length > 0;
  }

  class ApiClient {
    /**
     * @param {Object} [options]
     * @param {string} [options.baseUrl]  base URL prepended to relative paths
     * @param {number} [options.timeoutMs] per-request timeout (default 8000)
     * @param {number} [options.retries]   retries for idempotent requests (default 2)
     * @param {number} [options.retryDelayMs] base backoff delay (default 300)
     * @param {typeof fetch} [options.fetchImpl] injectable fetch (tests)
     */
    constructor(options) {
      const o = options || {};
      this.baseUrl = o.baseUrl || '';
      this.timeoutMs = typeof o.timeoutMs === 'number' ? o.timeoutMs : 8000;
      this.retries = typeof o.retries === 'number' ? o.retries : 2;
      this.retryDelayMs = typeof o.retryDelayMs === 'number' ? o.retryDelayMs : 300;
      this.fetchImpl = o.fetchImpl || (typeof fetch !== 'undefined' ? fetch.bind(globalThis) : null);
      if (!this.fetchImpl) {
        throw new ApiError('No fetch implementation available in this environment', {
          code: 'NO_FETCH',
          status: 0,
          retryable: false
        });
      }
    }

    /**
     * Perform a request and return the parsed JSON body.
     * @template T
     * @param {string} path
     * @param {{method?:string, body?:*, headers?:Object, timeoutMs?:number, retries?:number}} [options]
     * @returns {Promise<T>}
     */
    async request(path, options) {
      const opts = options || {};
      const method = (opts.method || 'GET').toUpperCase();
      // Only retry idempotent methods by default; callers can opt in explicitly.
      const maxRetries = typeof opts.retries === 'number'
        ? opts.retries
        : (method === 'GET' || method === 'HEAD' ? this.retries : 0);
      const timeoutMs = typeof opts.timeoutMs === 'number' ? opts.timeoutMs : this.timeoutMs;

      let attempt = 0;
      /** @type {ApiError|null} */
      let lastError = null;

      while (attempt <= maxRetries) {
        try {
          return await this._attempt(path, method, opts, timeoutMs);
        } catch (err) {
          const apiErr = err instanceof ApiError
            ? err
            : new ApiError(String(err && err.message || err), { code: 'UNKNOWN', status: 0, retryable: false });
          lastError = apiErr;
          const canRetry = apiErr.retryable && attempt < maxRetries;
          if (!canRetry) throw apiErr;
          attempt += 1;
          await sleep(this.retryDelayMs * attempt);
        }
      }
      throw lastError || new ApiError('Request failed', { code: 'UNKNOWN', status: 0 });
    }

    /**
     * @private
     */
    async _attempt(path, method, opts, timeoutMs) {
      const url = /^https?:\/\//i.test(path) ? path : this.baseUrl + path;
      const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const timer = controller ? setTimeout(function () { controller.abort(); }, timeoutMs) : null;

      const headers = Object.assign({ Accept: 'application/json' }, opts.headers || {});
      let body;
      if (opts.body !== undefined && opts.body !== null) {
        headers['Content-Type'] = headers['Content-Type'] || 'application/json';
        body = isNonEmptyString(opts.body) || typeof opts.body === 'object' ? (typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body)) : String(opts.body);
      }

      let res;
      try {
        res = await this.fetchImpl(url, {
          method: method,
          headers: headers,
          body: body,
          signal: controller ? controller.signal : undefined
        });
      } catch (err) {
        if (timer) clearTimeout(timer);
        const aborted = err && err.name === 'AbortError';
        throw new ApiError(
          aborted ? 'Request timed out after ' + timeoutMs + 'ms' : 'Network request failed',
          {
            code: aborted ? 'TIMEOUT' : 'NETWORK_ERROR',
            status: 0,
            retryable: true,
            details: err && err.message ? String(err.message) : null
          }
        );
      }
      if (timer) clearTimeout(timer);

      const text = await res.text();
      let data = null;
      if (text) {
        try { data = JSON.parse(text); } catch (e) { data = text; }
      }

      if (!res.ok) {
        const errObj = data && typeof data === 'object' ? data.error : null;
        const message = (errObj && errObj.message) || (data && data.message) || ('HTTP ' + res.status);
        throw new ApiError(message, {
          code: (errObj && errObj.code) || ('HTTP_' + res.status),
          status: res.status,
          retryable: res.status >= 500 || res.status === 429,
          details: data
        });
      }
      return data;
    }

    /** @returns {Promise<HealthResponse>} */
    health() { return this.request('/api/health'); }

    /** @returns {Promise<InfoResponse>} */
    info() { return this.request('/api/info'); }

    /** @returns {Promise<DbStatusResponse>} */
    dbStatus() { return this.request('/api/db-status'); }

    /**
     * @param {ConnectDbRequest} payload
     * @returns {Promise<DbStatusResponse>}
     */
    connectDb(payload) { return this.request('/api/connect-db', { method: 'POST', body: payload, retries: 0 }); }

    /**
     * @param {string} command
     * @returns {Promise<ExecResponse>}
     */
    exec(command) { return this.request('/api/exec', { method: 'POST', body: { command: command }, retries: 0 }); }
  }

  return { ApiClient: ApiClient, ApiError: ApiError };
});
