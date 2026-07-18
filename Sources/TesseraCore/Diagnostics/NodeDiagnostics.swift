import TesseraTerminalCore

/// Immutable geometry and reconciliation information for one runtime node.
public struct NodeDiagnostics: Equatable, Sendable {
  public let identity: NodeIdentity
  public let viewType: String
  public let parentIdentity: NodeIdentity?
  public let childIdentities: [NodeIdentity]
  public let proposal: ProposedSize?
  public let measuredSize: TerminalSize?
  public let frame: Rect
  public let clip: Rect
  public let environmentOverrides: [String]
  public let handlerKinds: [String]
  public let requestedTerminalRequirements: TerminalRequirements
  public let needsLayout: Bool
  public let needsRender: Bool

  public init(
    identity: NodeIdentity,
    viewType: String,
    parentIdentity: NodeIdentity?,
    childIdentities: [NodeIdentity],
    proposal: ProposedSize?,
    measuredSize: TerminalSize?,
    frame: Rect,
    clip: Rect,
    environmentOverrides: [String],
    handlerKinds: [String],
    requestedTerminalRequirements: TerminalRequirements,
    needsLayout: Bool,
    needsRender: Bool
  ) {
    self.identity = identity
    self.viewType = viewType
    self.parentIdentity = parentIdentity
    self.childIdentities = childIdentities
    self.proposal = proposal
    self.measuredSize = measuredSize
    self.frame = frame
    self.clip = clip
    self.environmentOverrides = environmentOverrides
    self.handlerKinds = handlerKinds
    self.requestedTerminalRequirements = requestedTerminalRequirements
    self.needsLayout = needsLayout
    self.needsRender = needsRender
  }
}
