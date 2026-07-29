// C:\nifdu\src\nifdu_chess_lab.cpp
//
// Minimal server-side NIFDU Chess Lab.
// Pure C++ generates pure HTML; the browser just renders it.
// No JS, no Python, no WASM.
//

#include <string>
#include <sstream>
#include <array>
#include <cstdint>
#include <algorithm>

namespace nifdu_chess_lab {

struct Move {
    uint8_t from;
    uint8_t to;
};

// 0..63, 0 = a1, 7 = h1, 56 = a8, 63 = h8
static const Move MOVES[] = {
    // 1. e4   e5
    { 12, 28 }, { 52, 36 },
    // 2. Nf3  Nc6
    {  6, 21 }, { 57, 42 },
    // 3. Bc4  Nf6
    {  5, 26 }, { 62, 45 },
    // 4. d3   Be7
    { 11, 19 }, { 61, 52 },
    // 5. Bg5  d6
    {  2, 30 }, { 51, 43 },
    // 6. Nc3  Bg4
    {  1, 18 }, { 58, 38 },
    // 7. Qh5  a6
    {  3, 31 }, { 48, 40 }
};

static constexpr int MOVE_COUNT = sizeof(MOVES) / sizeof(MOVES[0]);

// Simple board representation: Unicode piece or ' '.
struct Board {
    std::array<char32_t, 64> piece{};
};

static inline int idx(int rank, int file) {
    return rank * 8 + file;
}

static Board initial_board()
{
    Board b{};
    // Clear
    std::fill(b.piece.begin(), b.piece.end(), U' ');

    // Black pieces (top, ranks 6–7)
    for (int file = 0; file < 8; ++file) {
        b.piece[idx(6, file)] = U'♟'; // pawns
    }
    {
        // rank 7
        const char32_t row[] = { U'♜', U'♞', U'♝', U'♛', U'♚', U'♝', U'♞', U'♜' };
        for (int file = 0; file < 8; ++file) {
            b.piece[idx(7, file)] = row[file];
        }
    }

    // White pieces (bottom, ranks 0–1)
    for (int file = 0; file < 8; ++file) {
        b.piece[idx(1, file)] = U'♙';
    }
    {
        const char32_t row[] = { U'♖', U'♘', U'♗', U'♕', U'♔', U'♗', U'♘', U'♖' };
        for (int file = 0; file < 8; ++file) {
            b.piece[idx(0, file)] = row[file];
        }
    }

    return b;
}

static void apply_move(Board& b, const Move& m)
{
    int from = m.from;
    int to   = m.to;
    if (from < 0 || from > 63 || to < 0 || to > 63) return;
    char32_t p = b.piece[(size_t)from];
    if (p == U' ') return;
    b.piece[(size_t)from] = U' ';
    b.piece[(size_t)to]   = p;
}

static std::string utf8_from_char32(char32_t c)
{
    // Only need BMP for chess pieces; quick and dirty UTF-8 encode.
    std::string out;
    uint32_t cp = static_cast<uint32_t>(c);
    if (cp <= 0x7F) {
        out.push_back(static_cast<char>(cp));
    } else if (cp <= 0x7FF) {
        out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp <= 0xFFFF) {
        out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
        out.push_back('?');
    }
    return out;
}

// Render full HTML page for given move index.
inline std::string render_page(int move_index, bool auto_5s)
{
    if (move_index < 0) move_index = 0;
    if (move_index > MOVE_COUNT) move_index = MOVE_COUNT;

    Board b = initial_board();
    for (int i = 0; i < move_index; ++i) {
        apply_move(b, MOVES[i]);
    }

    int ply = move_index;
    int full_move = ply / 2 + 1;
    bool white_to_move = (ply % 2 == 0);

    std::ostringstream html;

    html << "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
         << "<meta charset=\"UTF-8\" />\n"
         << "<title>NIFDU Chess Lab - C++ only</title>\n"
         << "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n";
    if (auto_5s) {
        // Auto-advance every 5 seconds
        int next = (move_index < MOVE_COUNT) ? (move_index + 1) : MOVE_COUNT;
        html << "<meta http-equiv=\"refresh\" content=\"5;url=/games/chess?move="
             << next << "&auto=1\" />\n";
    }
    html << "<style>\n"
         << "body{margin:0;min-height:100vh;background:#02030a;color:#f4f7ff;"
         << "font-family:system-ui,-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;"
         << "display:flex;justify-content:center;align-items:stretch;}\n"
         << ".app{width:100%;max-width:1200px;padding:12px;display:grid;"
         << "grid-template-columns:minmax(0,3fr)minmax(0,2fr);gap:12px;}\n"
         << ".card{background:linear-gradient(145deg,#050816,#02030a);border-radius:18px;"
         << "border:1px solid rgba(255,255,255,0.08);padding:10px 12px;"
         << "box-shadow:0 18px 40px rgba(0,0,0,0.65);}\n"
         << ".title{font-size:16px;font-weight:600;letter-spacing:0.03em;text-transform:uppercase;}\n"
         << ".subtitle{font-size:11px;color:#9ba3c1;margin-top:2px;}\n"
         << ".board{border-radius:14px;overflow:hidden;border:1px solid rgba(255,255,255,0.09);"
         << "background:#050810;display:grid;grid-template-columns:repeat(8,1fr);}\n"
         << ".sq{display:flex;align-items:center;justify-content:center;font-size:18px;font-weight:600;"
         << "height:50px;}\n"
         << ".a{background:#0a1728;} .b{background:#10351a;} .c{background:#3a1020;}"
         << ".d{background:#2b1a45;} .e{background:#3b2a12;} .f{background:#20353b;}\n"
         << ".white{color:#ffd6a0;} .black{color:#d0ddff;}\n"
         << ".controls{margin-top:8px;font-size:12px;}\n"
         << ".controls a,.controls button{display:inline-block;margin:2px 4px;padding:6px 12px;"
         << "border-radius:999px;border:1px solid rgba(255,255,255,0.08);"
         << "background:linear-gradient(135deg,#121931,#050816);color:#f4f7ff;text-decoration:none;font-size:11px;}\n"
         << ".controls a.primary{border-color:#00e0ff;}\n"
         << ".controls a.danger{border-color:#ff4f81;color:#ff4f81;}\n"
         << ".logs{font-size:11px;background:#050816;border-radius:16px;border:1px solid rgba(255,255,255,0.08);"
         << "padding:8px;}\n"
         << ".logline{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-bottom:2px;}\n"
         << "@media(max-width:1000px){.app{grid-template-columns:1fr;max-width:900px;}}\n"
         << "</style>\n</head>\n<body>\n<div class=\"app\">\n";

    // LEFT: board & controls
    html << "<div class=\"card\">\n";
    html << "<div class=\"title\">NIFDU Chess Lab</div>\n";
    html << "<div class=\"subtitle\">C++ server - HTML only · Move "
         << full_move << (white_to_move ? " · White to move" : " · Black to move")
         << "</div>\n";

    // Board
    html << "<div class=\"board\" style=\"margin-top:8px;\">\n";
    // We draw from Black side at top: rank 7 down to 0
    for (int rank = 7; rank >= 0; --rank) {
        for (int file = 0; file < 8; ++file) {
            int index = idx(rank, file);
            char32_t p = b.piece[(size_t)index];
            bool is_white = (p == U'♙' || p == U'♖' || p == U'♘' ||
                             p == U'♗' || p == U'♕' || p == U'♔');
            const char* sqClass = "a";
            switch ((rank + file) % 6) {
                case 0: sqClass = "a"; break;
                case 1: sqClass = "b"; break;
                case 2: sqClass = "c"; break;
                case 3: sqClass = "d"; break;
                case 4: sqClass = "e"; break;
                case 5: sqClass = "f"; break;
            }
            html << "<div class=\"sq " << sqClass;
            if (p != U' ') {
                html << (is_white ? " white" : " black");
            }
            html << "\">";
            if (p != U' ') {
                html << utf8_from_char32(p);
            }
            html << "</div>\n";
        }
    }
    html << "</div>\n";

    // Controls (links do full reload => new HTML from C++)
    html << "<div class=\"controls\">\n";
    // Step link
    int next = (move_index < MOVE_COUNT) ? (move_index + 1) : MOVE_COUNT;
    html << "<a class=\"primary\" href=\"/games/chess?move=" << next
         << (auto_5s ? "&auto=1" : "") << "\">Next move</a>\n";

    // Auto toggle
    if (!auto_5s) {
        html << "<a href=\"/games/chess?move=" << move_index
             << "&auto=1\">Auto (5s)</a>\n";
    } else {
        html << "<a href=\"/games/chess?move=" << move_index
             << "\">Stop auto</a>\n";
    }

    // Reset
    html << "<a class=\"danger\" href=\"/games/chess?move=0\">Reset</a>\n";
    html << "</div>\n";

    html << "</div>\n"; // end left card

    // RIGHT: simple log / commentary
    html << "<div class=\"card\">\n<div class=\"logs\">\n";
    html << "<div style=\"font-weight:600;margin-bottom:4px;\">Move log</div>\n";

    if (move_index == 0) {
        html << "<div class=\"logline\">Game not started yet. Click "
             << "<strong>Next move</strong> to begin the fixed opening sequence.</div>\n";
    } else {
        for (int i = 0; i < move_index; ++i) {
            bool white = (i % 2 == 0);
            int mnum = i / 2 + 1;
            html << "<div class=\"logline\">";
            html << mnum << (white ? ". " : "... ");
            html << (white ? "White" : "Black")
                 << " plays move #" << (i + 1) << " (precomputed C++ sequence)";
            html << "</div>\n";
        }
    }

    html << "<div style=\"margin-top:8px;color:#9ba3c1;\">";
    html << "This page is rendered entirely by the NIFDU C++ server. "
         << "Every click returns a new HTML snapshot &mdash; no JavaScript, no Python.";
    html << "</div>\n";

    html << "</div>\n</div>\n"; // logs card, right col

    html << "</div>\n</body>\n</html>\n";

    return html.str();
}

} // namespace nifdu_chess_lab
