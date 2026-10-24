/// Shell-style tokenizer: whitespace separated, `"…"` with escapes, `'…'` literal,
/// `#` starts a comment at a token boundary.
///
/// A carriage return is whitespace, so a line read from a CRLF file tokenizes as it would
/// from an LF file.
enum Tokenizer {
  struct Failure: Error {
    var message: String
  }

  /// The escapes a double-quoted string accepts, for the error that names them.
  static let escapes = #"\n \t \" \\ \xHH"#

  static func tokens(in line: String) throws -> [String] {
    var tokens: [String] = []
    var current = ""
    var inToken = false
    var iterator = line.makeIterator()
    var pending = iterator.next()

    func flush() {
      if inToken {
        tokens.append(current)
        current = ""
        inToken = false
      }
    }

    while let character = pending {
      pending = iterator.next()
      switch character {
      case " ", "\t", "\r":
        flush()
      case "#" where !inToken:
        pending = nil
      case "\"":
        inToken = true
        var closed = false
        while let next = pending {
          pending = iterator.next()
          if next == "\"" {
            closed = true
            break
          }
          if next == "\\" {
            guard let escaped = pending else {
              throw Failure(message: "dangling backslash in quoted string")
            }
            pending = iterator.next()
            switch escaped {
            case "n": current.append("\n")
            case "t": current.append("\t")
            case "\"", "\\": current.append(escaped)
            case "x":
              guard let high = pending?.hexDigitValue else {
                throw Failure(message: "`\\x` needs two hex digits, as in `\\x1b`")
              }
              pending = iterator.next()
              guard let low = pending?.hexDigitValue else {
                throw Failure(message: "`\\x` needs two hex digits, as in `\\x1b`")
              }
              pending = iterator.next()
              let value = high * 16 + low
              guard value < 0x80 else {
                throw Failure(
                  message:
                    "`\\x` escapes are ASCII (00 to 7f); write a non-ASCII character itself"
                )
              }
              current.append(Character(Unicode.Scalar(UInt8(value))))
            default:
              throw Failure(
                message: "unknown escape `\\\(escaped)`; accepted: \(escapes)")
            }
          } else {
            current.append(next)
          }
        }
        guard closed else { throw Failure(message: "unterminated double quote") }
      case "'":
        inToken = true
        var closed = false
        while let next = pending {
          pending = iterator.next()
          if next == "'" {
            closed = true
            break
          }
          current.append(next)
        }
        guard closed else { throw Failure(message: "unterminated single quote") }
      default:
        inToken = true
        current.append(character)
      }
    }
    flush()
    return tokens
  }
}
