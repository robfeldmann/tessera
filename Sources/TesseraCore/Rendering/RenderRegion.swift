import TesseraTerminalBuffer

/// The view layer's borrowed, clipped drawing capability.
///
/// `RenderRegion` is backed by the terminal-buffer module so the frame's private borrowed
/// storage remains encapsulated there. It exposes no terminal session or I/O authority.
public typealias RenderRegion = FrameRegion
