'use strict';

/**
 * Unit tests for the shared API client (lib/apiClient.js).
 *
 * These run with the Node built-in test runner: `node --test`.
 * The fetch implementation is injected so no network access is required.
 */

const test = require('node:test');
const assert = require('node:assert');

const { ApiClient, ApiError } = require('../lib/apiClient.js');

/** Build a fake Response-like object. */
function response(status, body, ok) {
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  return {
    ok: ok === undefined ? status >= 200 && status < 300 : ok,
    status: status,
    text: async function () { return text; }
  };
}

test('parse: returns parsed JSON on a 200 response', async function () {
  const client = new ApiClient({
    baseUrl: '',
    fetchImpl: async function () { return response(200, { status: 'UP' }); }
  });
  const data = await client.health();
  assert.strictEqual(data.status, 'UP');
});

test('error: throws ApiError with server error code and message', async function () {
  const client = new ApiClient({
    fetchImpl: async function () {
      return response(400, { error: { code: 'VALIDATION_ERROR', message: 'host is required' } });
    }
  });
  await assert.rejects(
    function () { return client.connectDb({ host: '' }); },
    function (err) {
      assert.ok(err instanceof ApiError, 'should be an ApiError');
      assert.strictEqual(err.code, 'VALIDATION_ERROR');
      assert.strictEqual(err.status, 400);
      assert.strictEqual(err.message, 'host is required');
      return true;
    }
  );
});

test('timeout: aborts and throws a non-retryable-when-exhausted TIMEOUT error', async function () {
  const client = new ApiClient({
    timeoutMs: 20,
    retries: 0,
    fetchImpl: function (url, init) {
      // Never resolves; reject only when the client aborts.
      return new Promise(function (_resolve, reject) {
        if (init && init.signal) {
          init.signal.addEventListener('abort', function () {
            const e = new Error('aborted');
            e.name = 'AbortError';
            reject(e);
          });
        }
      });
    }
  });
  await assert.rejects(
    function () { return client.info(); },
    function (err) {
      assert.strictEqual(err.code, 'TIMEOUT');
      assert.strictEqual(err.retryable, true);
      return true;
    }
  );
});

test('retry: retries GET on 500 and eventually succeeds', async function () {
  let calls = 0;
  const client = new ApiClient({
    retries: 2,
    retryDelayMs: 1,
    fetchImpl: async function () {
      calls += 1;
      if (calls < 3) return response(500, { error: { message: 'boom' } });
      return response(200, { status: 'UP' });
    }
  });
  const data = await client.health();
  assert.strictEqual(calls, 3);
  assert.strictEqual(data.status, 'UP');
});

test('retry: does not retry a POST (connect-db) on 500', async function () {
  let calls = 0;
  const client = new ApiClient({
    retries: 2,
    retryDelayMs: 1,
    fetchImpl: async function () {
      calls += 1;
      return response(500, { error: { message: 'boom' } });
    }
  });
  await assert.rejects(function () { return client.connectDb({ host: 'db' }); });
  assert.strictEqual(calls, 1, 'POST must not be retried');
});

test('network: wraps a thrown fetch error as NETWORK_ERROR', async function () {
  const client = new ApiClient({
    retries: 0,
    fetchImpl: async function () { throw new Error('ECONNREFUSED'); }
  });
  await assert.rejects(
    function () { return client.health(); },
    function (err) {
      assert.strictEqual(err.code, 'NETWORK_ERROR');
      assert.strictEqual(err.status, 0);
      return true;
    }
  );
});
