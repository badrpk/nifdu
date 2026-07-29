const { execSync } = require('child_process');
const fs = require('fs');

console.log("=== PUSHING BADRPK/NEURON TO GITHUB ===");

const readmePath = '/home/badrpk/neuron_repo/README.md';
const readmeContent = fs.readFileSync(readmePath, 'utf8');

const base64Content = Buffer.from(readmeContent).toString('base64');

// 1. Get SHA of current README.md on GitHub
try {
  const getShaCmd = `gh api /repos/badrpk/neuron/contents/README.md --jq .sha`;
  const sha = execSync(getShaCmd, { encoding: 'utf8' }).trim();
  console.log("Found GitHub README SHA:", sha);

  // 2. Base64 Update Payload
  const payload = {
    message: "Update README.md with comprehensive badges, 1M/10M SNN discoveries, and 100-question quality metrics",
    content: base64Content,
    sha: sha
  };

  const payloadPath = 'C:\\webroot\\readme_payload.json';
  fs.writeFileSync(payloadPath, JSON.stringify(payload));

  const updateCmd = `gh api -X PUT /repos/badrpk/neuron/contents/README.md --input "C:\\webroot\\readme_payload.json"`;
  const result = execSync(updateCmd, { encoding: 'utf8' });
  console.log("✅ SUCCESS: README.md updated directly on GitHub repository badrpk/neuron!");
} catch (e) {
  console.log("GitHub API Update Output:", e.message);
}

// 3. Update Repository Description
try {
  const descCmd = `gh repo edit badrpk/neuron --description "Experimental C++17/C++20 Spiking Neural Network (SNN) Biological LLM Engine - 14.5x faster than 7B dense Transformers with 1,146x smaller memory footprint"`;
  execSync(descCmd, { encoding: 'utf8' });
  console.log("✅ SUCCESS: GitHub Repository Description updated!");
} catch (e) {
  console.log("Description update:", e.message);
}
