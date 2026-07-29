NIFDU Agent3 wrapper installed to: C:\nifdu\ops\agent3

Run:
  powershell -ExecutionPolicy Bypass -File C:\nifdu\ops\agent3\agent3_run.ps1 
    -ProjectRoot C:\nifdu\src\apps\sophyane_live 
    -Prompt "Fix the vibe coding UI: chat left, code middle, preview right" 
    -Mode next 
    -Domain sophyane.com 
    -TestMode local

Outputs (per project):
  <project>\.nifdu\agent3_state.json
  <project>\.nifdu\runs\<runid>.jsonl
  <project>\.nifdu\runs\<runid>.html
  <project>\.nifdu\backups\iter_*\

Brain endpoint (default):
  http://127.0.0.1:8000/api/codegen

Expected brain response JSON shape (any one works):
  { files:[{path:"components/Header.tsx", content:"..."}] }
  { edits:[{path:"components/Header.tsx", find:"Linkhref", replace:"Link href"}] }
  { patches:[{path:"components/Header.tsx", unified_diff:"@@ -1,2 +1,2 @@ ..."}] }