/// What `help` prints: the overview, and one description for each command.
enum HelpText {
  static let overview = """
    usage: <executable> COMMAND [ARGUMENT...]

    commands:
      apps              list the registered applications
      launch NAME       run one application in this terminal
      run PATH...       run scenario files, or directories of them
      shot NAME [SIZE]  print one application's screen as text
      tree NAME [SIZE]  print one application's node tree
      help [COMMAND]    describe a command

    Every command exits 0 on success, 1 when an expectation failed, 2 on a usage or parse
    error, and 3 on a harness error. When standard output is not a terminal each command
    writes one JSON object to it; --json forces that form and --pretty forces the text form.
    """

  static let commands: [String: String] = [
    "apps": """
    usage: apps [--json | --pretty]

    Lists every registered application with the smallest size it declares and the
    viewports it is checked at. The JSON form is {"apps": [{"minimum", "name",
    "viewports"}], "command": "apps"}, sorted by name, where "minimum" is null for an
    application that declares none. A name registered twice fails the command with exit 3.
    """,
    "launch": """
    usage: launch NAME

    Runs the named application in this terminal at the terminal's size, until the
    application finishes. The harness has no quit key of its own: the application decides
    which key quits. Exits 2 for an unknown name, and 3 for a duplicate registration or
    when standard input or output is not a terminal.
    """,
    "run": """
    usage: run PATH... [--record] [--repeat N] [--timing] [--json | --pretty]

    Runs scenario files. A PATH is a .scn file, or a directory whose .scn files, at any
    depth, run in sorted order. A path that is neither, or a directory with no scenarios, is
    a usage error. Each scenario starts a fresh application.

    A scenario is a text file with one statement per line. The header statements are
    `app NAME`, `size SIZE`, and `term colors=... theme=...`. The input statements are
    `resize WxH`, `key NAME`, `type "text"`, `paste "text"`, and `bytes "..."`. `shot NAME`
    compares the screen with a golden file and `tree` adds the node tree to the report. The
    assertions are `expect text [ROW] "text"`, `expect screen <<WORD`, and
    `expect node SEL frame X,Y,WxH`. A statement outside this list is a parse error.

      --record     write the golden files that `shot` statements compare against, instead
                   of failing when one differs or is missing, and list what changed. Review
                   the files it wrote; never record to make a failing run pass.
      --repeat N   run each scenario N times, and fail a run whose report differs from the
                   first.
      --timing     add the wall-clock seconds of each run to the report. Times differ from
                   run to run, so they are never golden.

    Exit codes: 0 every scenario passed, 1 an expectation failed, 2 a scenario did not parse
    or a path is not a scenario, 3 a harness error. When several apply, the highest wins.

    The JSON form is {"command": "run", "exitCode", "scenarios": [REPORT...]} with one
    REPORT per scenario: {"failures": [FAILURE...], "observations": [{"line", "verb",
    "lines"} and, for a shot, "name"], "passed", "recorded" (only when --record wrote
    goldens: [{"change": "created" or "updated", "path"}]), "scenario", "seconds" (only with
    --timing)}. A FAILURE is {"line", "statement", "verb", "message"} and, when the
    statement compares values, "expected", "actual", and "screen". A failure that belongs to
    a file or a command, not a line, has "line" 0 and "statement" "" (a repeat failure's
    statement is "--repeat N"). A shot whose golden is missing, is not UTF-8, or has CRLF
    line endings has no "expected", "actual", or "screen": its observation holds the screen.
    A scenario that does not parse is a failure with verb "parse". Fields are added, never
    removed or renamed.
    """,
    "shot": """
    usage: shot NAME [SIZE] [--json | --pretty]

    Prints the screen of the registered application NAME, as text, the way a golden file
    holds it. SIZE is desktop, mobile, mobileScreen, or WxH, and defaults to desktop. The
    JSON form is {"app", "command": "shot", "exitCode", "rows", "size"}, where "size" is the
    terminal size the application was shown at. An unknown NAME is a usage error that lists
    the registered names, and so is a size the application cannot take, such as `mobile` for
    an application whose content fills any height: the error says which size to use.
    """,
    "tree": """
    usage: tree NAME [SIZE] [--json | --pretty]

    Prints the node tree of the registered application NAME, one line per node with its
    identity, type, frame, and clip. SIZE is desktop, mobile, mobileScreen, or WxH, and
    defaults to desktop. The JSON form is {"app", "command": "tree", "exitCode", "lines",
    "size"}. The tree's text is for reading and is not promised to stay as it is. Errors are
    those of `shot`.
    """,
    "help": """
    usage: help [COMMAND]

    Prints the commands, or one command's usage.
    """,
  ]
}
