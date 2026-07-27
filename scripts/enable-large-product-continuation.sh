#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="$ROOT/src/main.cpp"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$MAIN.backup-$STAMP"

[[ -f "$MAIN" ]] || { echo "ERROR: $MAIN not found" >&2; exit 1; }
cp "$MAIN" "$BACKUP"

python3 - "$MAIN" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
original = s

s = s.replace(
    "constexpr long REQUEST_TIMEOUT_SECONDS = 120;",
    "constexpr long REQUEST_TIMEOUT_SECONDS = 300;",
    1,
)

# Give complex single-file products enough response budget.
old_generation = '''                {
                    {"temperature", temperature}
                }
'''
new_generation = '''                {
                    {"temperature", temperature},
                    {"maxOutputTokens", 65536}
                }
'''
if old_generation not in s:
    raise SystemExit("ERROR: generationConfig block not found")
s = s.replace(old_generation, new_generation, 1)

# Make the initial builder prioritise complete executable source over decoration.
old_initial = '''        return strip_markdown_fence(
            generate_text(
                builder_model_,
                instruction,
                0.7
            )
        );
'''
new_initial = '''        return complete_html(
            requirement,
            strip_markdown_fence(
                generate_text(
                    builder_model_,
                    instruction +
                        "\\nKeep CSS compact. Prioritise complete executable "
                        "JavaScript over decorative content. End with "
                        "</script></body></html>.",
                    0.45
                )
            )
        );
'''
if old_initial not in s:
    raise SystemExit("ERROR: build_initial return block not found")
s = s.replace(old_initial, new_initial, 1)

old_repair = '''        return strip_markdown_fence(
            generate_text(
                builder_model_,
                instruction.str(),
                0.35
            )
        );
'''
new_repair = '''        return complete_html(
            requirement,
            strip_markdown_fence(
                generate_text(
                    builder_model_,
                    instruction.str() +
                        "\\nThe response must be complete executable HTML. "
                        "Keep unchanged working code compact and end with "
                        "</script></body></html>.",
                    0.25
                )
            )
        );
'''
if old_repair not in s:
    raise SystemExit("ERROR: repair return block not found")
s = s.replace(old_repair, new_repair, 1)

marker = '''    static std::string endpoint(
        const std::string& model
    ) {
'''
helper = r'''    std::string complete_html(
        const std::string& requirement,
        std::string html
    ) const {
        constexpr int max_continuations = 4;

        for (int part = 1; part <= max_continuations; ++part) {
            const std::string lowered = lower(html);
            if (lowered.find("</html>") != std::string::npos) {
                return html;
            }

            const std::size_t tail_size = 14000;
            const std::string tail = html.size() > tail_size
                ? html.substr(html.size() - tail_size)
                : html;

            std::ostringstream prompt;
            prompt
                << "Continue an HTML document that was cut off by an output "
                << "limit. Return ONLY the exact missing continuation, not "
                << "Markdown and not the already supplied prefix. Start at "
                << "the precise point where the tail ends. Close every open "
                << "JavaScript, CSS and HTML construct, and finish with "
                << "</script></body></html>. Preserve the requested features.\n\n"
                << "CUSTOMER REQUEST:\n" << requirement << "\n\n"
                << "CURRENT DOCUMENT TAIL:\n" << tail;

            std::string continuation = strip_markdown_fence(
                generate_text(builder_model_, prompt.str(), 0.15)
            );

            if (trim(continuation).empty()) {
                break;
            }

            html += continuation;
        }

        return html;
    }

'''
if marker not in s:
    raise SystemExit("ERROR: GeminiClient private marker not found")
s = s.replace(marker, helper + marker, 1)

if s == original:
    raise SystemExit("ERROR: no changes made")

p.write_text(s, encoding="utf-8")
print("Patched:", p)
PY

cd "$ROOT"
rm -rf build
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build --target nifdu -j2

if [[ -n "${PREFIX:-}" && -d "$PREFIX/bin" ]]; then
    cp build/nifdu "$PREFIX/bin/nifdu-bin"
    chmod +x "$PREFIX/bin/nifdu-bin"
    echo "Installed: $PREFIX/bin/nifdu-bin"
fi

echo "Backup: $BACKUP"
echo "Large-product continuation upgrade completed."
