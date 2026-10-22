/// Formats a value in hundredths of a user unit without `Double` formatting.
///
/// `960` becomes `9.6`, `1500` becomes `15`, and `5` becomes `0.05`. Integer arithmetic
/// keeps the output identical on every platform, unlike `String(describing: Double)`.
func formatHundredths(_ value: Int) -> String {
  let sign = value < 0 ? "-" : ""
  let magnitude = value.magnitude
  let whole = magnitude / 100
  let fraction = magnitude % 100
  if fraction == 0 {
    return "\(sign)\(whole)"
  }
  if fraction % 10 == 0 {
    return "\(sign)\(whole).\(fraction / 10)"
  }
  let padded = fraction < 10 ? "0\(fraction)" : "\(fraction)"
  return "\(sign)\(whole).\(padded)"
}
