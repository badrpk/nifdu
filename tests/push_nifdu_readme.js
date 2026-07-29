const { execSync } = require('child_process');
const fs = require('fs');

console.log("=== PUSHING BADRPK/NIFDU README.MD TO GITHUB API ===");

const readmePath = '/mnt/c/nifdu/README.md';
const readmeContent = fs.readFileSync(readmePath, 'utf8');
const base64Content = Buffer.from(readmeContent).toString('base64');

try {
  const getShaCmd = `gh api /repos/badrpk/nifdu/contents/README.md --jq .sha`;
  const sha = execSync(getShaCmd, { encoding: 'utf8' }).trim();
  console.log("Found badrpk/nifdu README SHA:", sha);

  const payload = {
    message: "Update README.md with Neuron Spiking SNN biological LLM benchmarks and public download instructions",
    content: base64Content,
    sha: sha
  };

  const payloadPath = 'C:\\webroot\\nifdu_readme_payload.json';
  fs.writeFileSync(payloadPath, JSON.stringify(payload));

  const updateCmd = `gh api -X PUT /repos/badrpk/nifdu/contents/README.md --input "C:\\webroot\\nifdu_readme_payload.json"`;
  const result = execSync(updateCmd, { encoding: 'utf8' });
  console.log("✅ SUCCESS: README.md updated directly on GitHub repository badrpk/nifdu!");
} catch (e) {
  console.log("GitHub API Update Error:", e.message);
}
