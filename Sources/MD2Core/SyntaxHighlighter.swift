import Foundation

enum SyntaxHighlighter {
    static func highlightedHTML(for code: String, language: String) -> String {
        let definition = LanguageDefinition(language: language)
        guard definition.hasSyntaxRules else {
            return escapeHTML(code)
        }

        let segments = segment(code, definition: definition)

        return segments.map { segment in
            switch segment.kind {
            case .comment:
                return #"<span class="tok-comment">\#(escapeHTML(segment.text))</span>"#
            case .string:
                return #"<span class="tok-string">\#(escapeHTML(segment.text))</span>"#
            case .plain:
                return highlightPlain(segment.text, definition: definition)
            }
        }.joined()
    }

    private static func segment(_ code: String, definition: LanguageDefinition) -> [Segment] {
        let characters = Array(code)
        var result: [Segment] = []
        var buffer = ""
        var index = 0

        func flushPlain() {
            guard !buffer.isEmpty else { return }
            result.append(Segment(kind: .plain, text: buffer))
            buffer = ""
        }

        while index < characters.count {
            if let marker = definition.lineComment,
               starts(with: marker, in: characters, at: index) {
                flushPlain()
                let start = index
                while index < characters.count, characters[index] != "\n" {
                    index += 1
                }
                result.append(Segment(kind: .comment, text: String(characters[start..<index])))
                continue
            }

            if let marker = definition.blockCommentStart,
               let endMarker = definition.blockCommentEnd,
               starts(with: marker, in: characters, at: index) {
                flushPlain()
                let start = index
                index += marker.count
                while index < characters.count, !starts(with: endMarker, in: characters, at: index) {
                    index += 1
                }
                if index < characters.count {
                    index += endMarker.count
                }
                result.append(Segment(kind: .comment, text: String(characters[start..<index])))
                continue
            }

            if definition.stringDelimiters.contains(characters[index]) {
                flushPlain()
                let delimiter = characters[index]
                let start = index
                index += 1
                var escaped = false

                while index < characters.count {
                    let character = characters[index]
                    index += 1

                    if escaped {
                        escaped = false
                    } else if character == "\\" {
                        escaped = true
                    } else if character == delimiter {
                        break
                    }
                }

                result.append(Segment(kind: .string, text: String(characters[start..<index])))
                continue
            }

            buffer.append(characters[index])
            index += 1
        }

        flushPlain()
        return result
    }

    private static func highlightPlain(_ text: String, definition: LanguageDefinition) -> String {
        let characters = Array(text)
        var result = ""
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if isIdentifierStart(character) {
                let start = index
                index += 1
                while index < characters.count, isIdentifierBody(characters[index]) {
                    index += 1
                }

                let token = String(characters[start..<index])
                if definition.keywords.contains(token) {
                    result += #"<span class="tok-keyword">\#(escapeHTML(token))</span>"#
                } else if definition.types.contains(token) {
                    result += #"<span class="tok-type">\#(escapeHTML(token))</span>"#
                } else if isFunctionName(at: index, in: characters) {
                    result += #"<span class="tok-function">\#(escapeHTML(token))</span>"#
                } else {
                    result += escapeHTML(token)
                }
                continue
            }

            if character.isNumber {
                let start = index
                index += 1
                while index < characters.count,
                      characters[index].isNumber || characters[index] == "." || characters[index] == "_" {
                    index += 1
                }
                result += #"<span class="tok-number">\#(escapeHTML(String(characters[start..<index])))</span>"#
                continue
            }

            result += escapeHTML(String(character))
            index += 1
        }

        return result
    }

    private static func isFunctionName(at index: Int, in characters: [Character]) -> Bool {
        var lookahead = index
        while lookahead < characters.count, characters[lookahead].isWhitespace {
            lookahead += 1
        }

        return lookahead < characters.count && characters[lookahead] == "("
    }

    private static func starts(with marker: String, in characters: [Character], at index: Int) -> Bool {
        let markerCharacters = Array(marker)
        guard index + markerCharacters.count <= characters.count else { return false }

        for offset in markerCharacters.indices where characters[index + offset] != markerCharacters[offset] {
            return false
        }

        return true
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private static func isIdentifierBody(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }

    private static func escapeHTML(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct Segment {
    let kind: SegmentKind
    let text: String
}

private enum SegmentKind {
    case plain
    case comment
    case string
}

private struct LanguageDefinition {
    let keywords: Set<String>
    let types: Set<String>
    let lineComment: String?
    let blockCommentStart: String?
    let blockCommentEnd: String?
    let stringDelimiters: Set<Character>

    var hasSyntaxRules: Bool {
        !keywords.isEmpty || !types.isEmpty || lineComment != nil || blockCommentStart != nil
    }

    init(language: String) {
        let normalized = language.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "++", with: "pp")
            .replacingOccurrences(of: "#", with: "sharp")

        let cLikeKeywords: Set<String> = [
            "break", "case", "catch", "class", "const", "continue", "default", "do", "else", "enum",
            "extern", "for", "if", "import", "interface", "namespace", "new", "private", "protected",
            "public", "return", "static", "struct", "switch", "throw", "throws", "try", "using", "while"
        ]
        let cLikeTypes: Set<String> = [
            "bool", "char", "double", "float", "int", "long", "short", "signed", "size_t", "string",
            "uint", "usize", "void"
        ]

        switch normalized {
        case "py", "python", "python3":
            keywords = [
                "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
                "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import",
                "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return",
                "True", "try", "while", "with", "yield"
            ]
            types = ["bool", "bytes", "dict", "float", "int", "list", "set", "str", "tuple"]
            lineComment = "#"
            blockCommentStart = nil
            blockCommentEnd = nil
            stringDelimiters = ["\"", "'"]

        case "sh", "shell", "bash", "zsh":
            keywords = [
                "case", "do", "done", "elif", "else", "esac", "export", "fi", "for", "function", "if",
                "in", "local", "readonly", "return", "set", "shift", "then", "until", "while"
            ]
            types = []
            lineComment = "#"
            blockCommentStart = nil
            blockCommentEnd = nil
            stringDelimiters = ["\"", "'", "`"]

        case "pl", "perl":
            keywords = [
                "continue", "die", "do", "else", "elsif", "for", "foreach", "if", "last", "my", "next",
                "our", "package", "redo", "return", "sub", "unless", "until", "use", "while"
            ]
            types = []
            lineComment = "#"
            blockCommentStart = nil
            blockCommentEnd = nil
            stringDelimiters = ["\"", "'"]

        case "go", "golang":
            keywords = [
                "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough",
                "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range",
                "return", "select", "struct", "switch", "type", "var"
            ]
            types = ["bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr"]
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'", "`"]

        case "rs", "rust":
            keywords = [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
                "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
                "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true",
                "type", "unsafe", "use", "where", "while"
            ]
            types = ["bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "isize", "str", "String", "u8", "u16", "u32", "u64", "usize", "Vec"]
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'"]

        case "java":
            keywords = cLikeKeywords.union([
                "abstract", "assert", "extends", "final", "finally", "implements", "instanceof", "native",
                "package", "strictfp", "super", "synchronized", "this", "transient", "volatile"
            ])
            types = cLikeTypes.union(["boolean", "byte", "Integer", "Long", "Object", "String"])
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'"]

        case "c", "h":
            keywords = cLikeKeywords.union(["auto", "goto", "register", "restrict", "typedef", "union", "volatile"])
            types = cLikeTypes.union(["FILE", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"])
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'"]

        case "cpp", "cplusplus", "cc", "cxx", "hpp":
            keywords = cLikeKeywords.union([
                "alignas", "alignof", "constexpr", "decltype", "delete", "explicit", "friend", "mutable",
                "noexcept", "nullptr", "operator", "override", "template", "typename", "virtual"
            ])
            types = cLikeTypes.union(["std", "string", "vector"])
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'"]

        case "swift":
            keywords = [
                "actor", "as", "associatedtype", "async", "await", "break", "case", "catch", "class",
                "continue", "defer", "do", "else", "enum", "extension", "false", "for", "func", "guard",
                "if", "import", "in", "init", "let", "nil", "private", "protocol", "public", "return",
                "self", "static", "struct", "switch", "throw", "throws", "true", "try", "var", "while"
            ]
            types = ["Array", "Bool", "Character", "Dictionary", "Double", "Float", "Int", "Set", "String", "UInt", "Void"]
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'"]

        case "js", "javascript", "ts", "typescript":
            keywords = cLikeKeywords.union(["async", "await", "debugger", "delete", "export", "extends", "false", "function", "let", "null", "of", "this", "true", "typeof", "undefined", "var"])
            types = ["Array", "BigInt", "Boolean", "Map", "Number", "Object", "Promise", "Set", "String", "Symbol"]
            lineComment = "//"
            blockCommentStart = "/*"
            blockCommentEnd = "*/"
            stringDelimiters = ["\"", "'", "`"]

        default:
            keywords = []
            types = []
            lineComment = nil
            blockCommentStart = nil
            blockCommentEnd = nil
            stringDelimiters = ["\"", "'"]
        }
    }
}
