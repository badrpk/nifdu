const http = require('http');
const WebSocket = require('ws');
const { app, server } = require('../backend/app.js');

async function runToughHarness() {
  console.log('====================================================');
  console.log('🚀 NIFDU AGENT-3 & CORE PLATFORM TOUGH HARNESS TEST');
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

  // Helper HTTP POST
  function postJSON(path, body, headers = {}) {
    return new Promise((resolve, reject) => {
      const data = JSON.stringify(body);
      const req = http.request({
        hostname: '127.0.0.1',
        port: 8009,
        path,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
          ...headers
        }
      }, (res) => {
        let buf = '';
        res.on('data', chunk => buf += chunk);
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(buf || '{}') }));
      });
      req.on('error', reject);
      req.write(data);
      req.end();
    });
  }

  // Helper HTTP GET
  function getJSON(path) {
    return new Promise((resolve, reject) => {
      http.get(`http://127.0.0.1:8009${path}`, (res) => {
        let buf = '';
        res.on('data', chunk => buf += chunk);
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(buf || '{}') }));
      }).on('error', reject);
    });
  }

  try {
    // 1. Health Check
    console.log('TEST 1: Platform Health Check');
    const health = await getJSON('/api/health');
    assert(health.status === 200 && health.body.status === 'ok', 'NIFDU backend health check ok');

    // 2. Agent-3 Plan Creation
    console.log('\nTEST 2: Agent-3 Plan Creation Harness');
    const planRes = await postJSON('/api/agent/plan', {
      session_id: 'tough_harness_sess_001',
      prompt: 'Build real-time high frequency trading dashboard with PostGIS telemetry map'
    });
    assert(planRes.status === 200 && planRes.body.plan.steps.length === 4, 'Agent-3 plan generated 4 steps');

    // 3. Agent-3 Step Execution
    console.log('\nTEST 3: Agent-3 Step Execution Engine');
    const stepRes = await postJSON('/api/agent/step', {
      session_id: 'tough_harness_sess_001',
      step_id: 1
    });
    assert(stepRes.status === 200 && stepRes.body.step.completed === true, 'Agent-3 step 1 marked completed');

    // 4. Agent-3 Event Logging
    console.log('\nTEST 4: Agent-3 Event Stream Log');
    const eventsRes = await getJSON('/api/agent/events?session_id=tough_harness_sess_001');
    assert(eventsRes.status === 200 && eventsRes.body.events.length >= 1, 'Agent-3 event stream recorded execution event');

    // 5. Diff Preview
    console.log('\nTEST 5: Visual Diff Preview Engine');
    const diffRes = await postJSON('/api/diff/preview', {
      filepath: '/home/badrpk/nifdu/src/main.cpp',
      new_content: '// Updated high frequency trading main loop\nint main() { return 0; }'
    });
    assert(diffRes.status === 200 && diffRes.body.patch.includes('+++'), 'Diff patch generated successfully');

    // 6. Undo Snapshot & Revert
    console.log('\nTEST 6: Undo Snapshot & Revert');
    const snapRes = await postJSON('/api/undo/snapshot', { files: ['/home/badrpk/nifdu/CMakeLists.txt'] });
    assert(snapRes.status === 200 && snapRes.body.snapshot_id, 'Undo snapshot created');

    const revRes = await postJSON('/api/undo/revert', { snapshot_id: snapRes.body.snapshot_id });
    assert(revRes.status === 200 && revRes.body.reverted_files === 1, 'Revert snapshot executed successfully');

    // 7. HMAC Device Auth
    console.log('\nTEST 7: HMAC Device Key Bootstrapping');
    const keyRes = await postJSON('/api/auth/key', { deviceId: 'test_harness_device_999' });
    assert(keyRes.status === 200 && keyRes.body.deviceSecret, 'Device HMAC key provisioned');

    // 8. Signed Telemetry Ingestion
    console.log('\nTEST 8: Signed Telemetry Ingestion & Mode Classifier');
    const telemRes = await postJSON('/api/telemetry', {
      points: [
        { at: '2026-07-26T14:40:00Z', lat: 33.700, lng: 73.060, alt_m: 520, speed_kmh: 75 },
        { at: '2026-07-26T14:40:10Z', lat: 33.705, lng: 73.065, alt_m: 520, speed_kmh: 80 }
      ]
    }, {
      'x-nifdu-deviceid': 'test_harness_device_999',
      'x-nifdu-signature': 'mock_hmac_sig_val'
    });
    assert(telemRes.status === 200 && telemRes.body.processed_points === 2, 'Telemetry points processed & classified');

    // 9. PostGIS GeoJSON Map Edges
    console.log('\nTEST 9: GeoJSON Vector Map Edge Serving');
    const edgesRes = await getJSON('/api/map/edges?min_samples=1');
    assert(edgesRes.status === 200 && edgesRes.body.type === 'FeatureCollection', 'GeoJSON FeatureCollection served');

    // 10. WebRTC TURN Credentials
    console.log('\nTEST 10: WebRTC TURN Ephemeral Credential Generator');
    const turnRes = await getJSON('/api/turn?username=harness_tester');
    assert(turnRes.status === 200 && turnRes.body.uris.length >= 2, 'TURN STUN/TURN URIs generated');

    // 11. WebSocket Realtime Chat & Signaling
    console.log('\nTEST 11: Realtime WebSocket Hub');
    const ws = new WebSocket('ws://127.0.0.1:8009/ws');

    await new Promise((resolve) => {
      ws.on('open', () => {
        ws.send(JSON.stringify({ type: 'join', convoId: 99 }));
      });
      ws.on('message', (msg) => {
        const payload = JSON.parse(msg.toString());
        if (payload.type === 'joined') {
          assert(payload.convoId === 99, 'WebSocket join conversation 99 confirmed');
          ws.close();
          resolve();
        }
      });
    });

  } catch (err) {
    console.error('Harness failure:', err);
    failed++;
  } finally {
    console.log('\n====================================================');
    console.log(`📊 HARNESS SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('====================================================\n');
    server.close();
    process.exit(failed === 0 ? 0 : 1);
  }
}

runToughHarness();
