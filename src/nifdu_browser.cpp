// C:\nifdu\src\nifdu_browser.cpp
//
// NIFDU Browser Engine — Phase 1
// - Minimal HTML tokenizer
// - Tiny DOM tree
// - Console "renderer"
// This is engine-only, no OS windows yet.

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <algorithm>
#include <cctype>

// ------------------------------
// Utility helpers
// ------------------------------

static std::string trim(const std::string& s) {
    std::size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) {
        ++start;
    }
    if (start == s.size()) return {};
    std::size_t end = s.size() - 1;
    while (end > start && std::isspace(static_cast<unsigned char>(s[end]))) {
        --end;
    }
    return s.substr(start, end - start + 1);
}

static std::string to_lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return s;
}

// ------------------------------
// DOM model
// ------------------------------

struct HtmlNode {
    std::string tag;   // e.g. "div", "#text"
    std::string text;  // for text nodes
    std::map<std::string, std::string> attrs;
    std::vector<std::unique_ptr<HtmlNode>> children;

    bool is_text() const { return tag == "#text"; }
};

// ------------------------------
// HTML tokenizer / parser
// ------------------------------

class HtmlParser {
public:
    explicit HtmlParser(const std::string& src)
        : m_src(src), m_pos(0) {}

    std::unique_ptr<HtmlNode> parse_document() {
        auto root = std::make_unique<HtmlNode>();
        root->tag = "document";

        while (!eof()) {
            auto node = parse_node();
            if (node) {
                root->children.emplace_back(std::move(node));
            } else {
                break;
            }
        }
        return root;
    }

private:
    const std::string& m_src;
    std::size_t m_pos;

    bool eof() const {
        return m_pos >= m_src.size();
    }

    char peek() const {
        return eof() ? '\0' : m_src[m_pos];
    }

    char get() {
        return eof() ? '\0' : m_src[m_pos++];
    }

    void skip_whitespace() {
        while (!eof() && std::isspace(static_cast<unsigned char>(peek()))) {
            get();
        }
    }

    std::unique_ptr<HtmlNode> parse_node() {
        if (eof()) return nullptr;

        if (peek() == '<') {
            // Tag or comment
            if (match("<!--")) {
                skip_comment();
                return nullptr;
            }

            if (match("</")) {
                // closing tag: caller handles it
                // here we just consume until '>'
                consume_until('>');
                if (!eof()) get(); // consume '>'
                return nullptr;
            }

            // opening tag
            return parse_element();
        } else {
            // text node
            return parse_text();
        }
    }

    bool match(const std::string& s) {
        if (m_src.compare(m_pos, s.size(), s) == 0) {
            m_pos += s.size();
            return true;
        }
        return false;
    }

    void consume_until(char ch) {
        while (!eof() && peek() != ch) {
            get();
        }
    }

    void skip_comment() {
        // we are after <!--
        while (!eof()) {
            if (match("-->")) break;
            get();
        }
    }

    std::unique_ptr<HtmlNode> parse_text() {
        std::string result;
        while (!eof() && peek() != '<') {
            result.push_back(get());
        }
        auto node = std::make_unique<HtmlNode>();
        node->tag = "#text";
        node->text = trim(result);
        if (node->text.empty()) {
            return nullptr;
        }
        return node;
    }

    std::unique_ptr<HtmlNode> parse_element() {
        if (get() != '<') return nullptr; // consume '<'

        skip_whitespace();
        std::string tag_name = parse_identifier();
        tag_name = to_lower(tag_name);

        auto node = std::make_unique<HtmlNode>();
        node->tag = tag_name;

        // attributes
        skip_whitespace();
        while (!eof() && peek() != '>' && peek() != '/') {
            auto [name, value] = parse_attribute();
            if (!name.empty()) {
                node->attrs[to_lower(name)] = value;
            }
            skip_whitespace();
        }

        // self-closing?
        bool self_closing = false;
        if (peek() == '/') {
            self_closing = true;
            get(); // '/'
        }

        if (peek() == '>') {
            get(); // '>'
        }

        if (self_closing || is_void_element(tag_name)) {
            return node;
        }

        // parse children until we hit </tag_name>
        while (!eof()) {
            if (peek() == '<' && m_src.compare(m_pos, 2, "</") == 0) {
                // possible closing tag
                std::size_t saved = m_pos;
                m_pos += 2; // skip "</"
                skip_whitespace();
                std::string closingName = to_lower(parse_identifier());
                skip_whitespace();
                if (peek() == '>') {
                    get(); // '>'
                }
                if (closingName == tag_name) {
                    // correct close tag
                    break;
                } else {
                    // mismatch: rollback and treat as text
                    m_pos = saved;
                }
            }

            auto child = parse_node();
            if (child) {
                node->children.emplace_back(std::move(child));
            } else {
                break;
            }
        }

        return node;
    }

    std::string parse_identifier() {
        std::string id;
        while (!eof()) {
            char c = peek();
            if (std::isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || c == ':') {
                id.push_back(get());
            } else {
                break;
            }
        }
        return id;
    }

    std::pair<std::string, std::string> parse_attribute() {
        skip_whitespace();
        std::string name = parse_identifier();
        if (name.empty()) return {"", ""};

        skip_whitespace();
        std::string value;
        if (peek() == '=') {
            get(); // '='
            skip_whitespace();
            if (peek() == '"' || peek() == '\'') {
                char quote = get();
                while (!eof() && peek() != quote) {
                    value.push_back(get());
                }
                if (!eof()) get(); // closing quote
            } else {
                while (!eof() && !std::isspace(static_cast<unsigned char>(peek())) &&
                       peek() != '>' && peek() != '/') {
                    value.push_back(get());
                }
            }
        } else {
            // boolean attribute
            value = "true";
        }
        return {name, value};
    }

    bool is_void_element(const std::string& tag) const {
        static const char* voidTags[] = {
            "area","base","br","col","embed","hr","img","input",
            "link","meta","param","source","track","wbr"
        };
        for (auto t : voidTags) {
            if (tag == t) return true;
        }
        return false;
    }
};

// ------------------------------
// Console renderer (Phase 1)
// ------------------------------

class ConsoleRenderer {
public:
    void render(const HtmlNode& root) const {
        std::cout << "=== NIFDU Browser Engine — Console Render ===\n";
        render_node(root, 0);
    }

private:
    void render_node(const HtmlNode& node, int depth) const {
        std::string indent(depth * 2, ' ');

        if (node.is_text()) {
            if (!node.text.empty()) {
                std::cout << indent << "TEXT: \"" << node.text << "\"\n";
            }
            return;
        }

        std::cout << indent << "<" << node.tag;
        if (!node.attrs.empty()) {
            for (const auto& [k, v] : node.attrs) {
                std::cout << " " << k << "=\"" << v << "\"";
            }
        }
        std::cout << ">\n";

        for (const auto& child : node.children) {
            render_node(*child, depth + 1);
        }
    }
};

// ------------------------------
// BrowserEngine façade
// ------------------------------

class BrowserEngine {
public:
    std::unique_ptr<HtmlNode> load_from_string(const std::string& html) {
        HtmlParser parser(html);
        return parser.parse_document();
    }

    std::unique_ptr<HtmlNode> load_from_file(const std::string& path) {
        std::ifstream in(path, std::ios::binary);
        if (!in) {
            throw std::runtime_error("Failed to open HTML file: " + path);
        }
        std::ostringstream oss;
        oss << in.rdbuf();
        return load_from_string(oss.str());
    }

    void render_to_console(const HtmlNode& doc) const {
        ConsoleRenderer renderer;
        renderer.render(doc);
    }
};

// ------------------------------
// Demo main()
// ------------------------------

int main(int argc, char** argv) {
    try {
        std::cout << "NIFDU Browser Engine — Phase 1 (HTML → DOM → console)\n";

        if (argc < 2) {
            std::cout << "Usage:\n"
                      << "  nifdu_browser.exe <path-to-html>\n\n"
                      << "Example:\n"
                      << "  nifdu_browser.exe C:/webroot/nifdu.com/www/games/chess.html\n";
            return 0;
        }

        std::string path = argv[1];

        BrowserEngine engine;
        auto doc = engine.load_from_file(path);
        if (!doc) {
            std::cerr << "Parsed document is empty.\n";
            return 1;
        }

        engine.render_to_console(*doc);
        return 0;
    } catch (const std::exception& ex) {
        std::cerr << "FATAL: " << ex.what() << "\n";
        return 1;
    }
}
