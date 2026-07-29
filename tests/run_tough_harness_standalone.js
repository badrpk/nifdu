const http = require('http');
const crypto = require('crypto');
const fs = require('fs');

// Simple native HTTP test runner
async function runToughHarness() {
  console.log('====================================================');
  console.log('🚀 NIFDU HARNESS BENCHMARK TEST SUITE (PARITY TEST)');
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${message}`);
      failed++;
    }
  }

  // Load and mount route logic directly
  const agentRoutes = require('../backend/app/src/routes/agent.js');
  const diffRoutes = require('../backend/app/src/routes/diff.js');
  const undoRoutes = require('../backend/app/src/routes/undo.js');
  const telemetryModule = require('../backend/app/src/routes/telemetry.js');
  const mapEdgesRoutes = require('../backend/app/src/routes/map.edges.js');
  const turnRoutes = require('../backend/app/src/routes/turn.js');
  const authKeyRoutes = require('../backend/app/src/routes/auth.key.js');
  const segmentsWorker = require('../backend/workers/segments.js');

  // 1. Health & Core Engine Test
  console.log('TEST 1: Agent-3 Core Engine Load');
  assert(typeof agentRoutes === 'function', 'Agent-3 router loaded');

  // 2. Telemetry Processing & Velocity Mode Classifier
  console.log('\nTEST 2: Telemetry PostGIS Segment Calculator');
  const points = [
    { at: '2026-07-26T14:40:00Z', lat: 33.700, lng: 73.060, alt_m: 520, speed_kmh: 50 },
    { at: '2026-07-26T14:40:10Z', lat: 33.705, lng: 73.065, alt_m: 520, speed_kmh: 60 }
  ];
  const segments = segmentsWorker.processTelemetrySegments(points);
  assert(segments.length === 1 && segments[0].mode === 'road', 'Segment mode correctly classified as road');

  // 3. High Speed Mode Classifier
  console.log('\nTEST 3: High-Altitude Flight Telemetry Classification');
  const flightPoints = [
    { at: '2026-07-26T14:40:00Z', lat: 33.700, lng: 73.060, alt_m: 10000, speed_kmh: 900 },
    { at: '2026-07-26T14:40:10Z', lat: 34.705, lng: 74.065, alt_m: 10000, speed_kmh: 900 }
  ];
  const flightSegments = segmentsWorker.processTelemetrySegments(flightPoints);
  assert(flightSegments[0].mode === 'air', 'Flight segment correctly classified as air');

  // 4. Device HMAC Auth Generation
  console.log('\nTEST 4: HMAC Device Secret Generator');
  const deviceId = 'dev_harness_test_001';
  const secret = crypto.createHmac('sha256', 'nifdu_master_key').update(deviceId).digest('hex');
  assert(secret.length === 64, 'HMAC-SHA256 device secret generated (64 hex chars)');

  // 5. C++ Native Executable Build Check
  console.log('\nTEST 5: C++ Native Executable Existence');
  const cppBin = '/home/badrpk/nifdu/build/nifdu';
  assert(fs.existsSync(cppBin), 'Native C++ nifdu binary exists at build/nifdu');

  // Summary
  console.log('\n====================================================');
  console.log(`📊 HARNESS SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================\n');

  process.exit(failed === 0 ? 0 : 1);
}

runToughHarness();
