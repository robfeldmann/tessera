"use strict"

const assert = require("node:assert/strict")
const test = require("node:test")

const {
  MAX_VOUCHED_BYTES,
  decodeVouchedFile,
  decisionFor,
  parseVouched,
  run,
} = require("./vouch-gate.cjs")

function encodedFile(text) {
  return {
    type: "file",
    encoding: "base64",
    content: Buffer.from(text, "utf8").toString("base64"),
  }
}

function makeHarness({
  author = "new-contributor",
  permission = "none",
  trust = "# empty\n",
} = {}) {
  const calls = {
    content: [],
    permission: [],
    reviews: [],
    updates: [],
    outputs: [],
    info: [],
  }
  const github = {
    rest: {
      repos: {
        async getContent(input) {
          calls.content.push(input)
          return { data: encodedFile(trust) }
        },
        async getCollaboratorPermissionLevel(input) {
          calls.permission.push(input)
          return { data: { permission, role_name: permission } }
        },
      },
      pulls: {
        async createReview(input) {
          calls.reviews.push(input)
        },
        async update(input) {
          calls.updates.push(input)
        },
      },
    },
  }
  const context = {
    repo: { owner: "robfeldmann", repo: "tessera" },
    payload: {
      repository: { default_branch: "main" },
      pull_request: {
        number: 42,
        user: { login: author },
        head: { ref: "attacker-controlled-branch" },
      },
    },
  }
  const core = {
    setOutput(name, value) {
      calls.outputs.push([name, value])
    },
    info(message) {
      calls.info.push(message)
    },
  }
  return { calls, context, core, github }
}

async function runHarness(options) {
  const harness = makeHarness(options)
  const result = await run(harness)
  return { ...harness, result }
}

test("the trust file accepts comments, blank lines, CRLF, and case-insensitive identities", () => {
  const entries = parseVouched(
    "# trusted people\r\n\r\n github:Alice \r\n-github:BOB\r\n",
  )
  assert.deepEqual(
    [...entries],
    [
      ["alice", "vouched"],
      ["bob", "denounced"],
    ],
  )
})

test("the trust file rejects malformed, duplicate, and conflicting entries", () => {
  const invalidFiles = [
    "alice\n",
    "github:-alice\n",
    "github:alice # inline comment\n",
    "github:alice\ngithub:ALICE\n",
    "github:alice\n-github:alice\n",
    "github:alice\r-github:bob\n",
    `github:${"a".repeat(40)}\n`,
  ]

  for (const contents of invalidFiles) {
    assert.throws(() => parseVouched(contents))
  }
})

test("the trust file rejects oversized and invalid encoded content", () => {
  assert.throws(() => parseVouched("a".repeat(MAX_VOUCHED_BYTES + 1)))
  assert.throws(() => decodeVouchedFile({ type: "dir" }))
  assert.throws(() =>
    decodeVouchedFile({ type: "file", encoding: "base64", content: "not base64" }),
  )
})

test("decisions allow only explicit automation, maintainers, and vouched contributors", () => {
  const entries = parseVouched("github:alice\n-github:bob\n")
  assert.equal(
    decisionFor({ author: "dependabot[bot]", permissionLevel: {}, entries }),
    "automation",
  )
  assert.equal(
    decisionFor({ author: "owner", permissionLevel: { permission: "admin" }, entries }),
    "maintainer",
  )
  assert.equal(
    decisionFor({ author: "Alice", permissionLevel: { permission: "none" }, entries }),
    "vouched",
  )
  assert.equal(
    decisionFor({ author: "bob", permissionLevel: { permission: "none" }, entries }),
    "denounced",
  )
  assert.equal(
    decisionFor({ author: "unknown", permissionLevel: { permission: "none" }, entries }),
    "unknown",
  )
})

test("vouched contributors pass without comments or pull request mutation", async () => {
  const { calls, result } = await runHarness({ author: "Alice", trust: "github:alice\n" })
  assert.equal(result, "vouched")
  assert.deepEqual(calls.reviews, [])
  assert.deepEqual(calls.updates, [])
})

test("unknown contributors receive process guidance and their pull request closes", async () => {
  const { calls, result } = await runHarness()
  assert.equal(result, "unknown")
  assert.equal(calls.reviews.length, 1)
  assert.match(calls.reviews[0].body, /separate, reviewed trust-list pull request/)
  assert.match(calls.reviews[0].body, /discussions\/new\?category=vouch-request/)
  assert.deepEqual(calls.updates, [
    { owner: "robfeldmann", repo: "tessera", pull_number: 42, state: "closed" },
  ])
})

test("denounced contributors follow the same non-disclosing public path", async () => {
  const { calls, result } = await runHarness({
    author: "blocked-user",
    trust: "-github:blocked-user\n",
  })
  assert.equal(result, "denounced")
  assert.doesNotMatch(calls.reviews[0].body, /denounc/i)
  assert.equal(calls.updates.length, 1)
})

test("the gate always reads trust from the default branch", async () => {
  const { calls } = await runHarness()
  assert.deepEqual(calls.content, [
    {
      owner: "robfeldmann",
      repo: "tessera",
      path: ".github/VOUCHED.td",
      ref: "main",
    },
  ])
})

test("malformed trust data fails without commenting on or closing the pull request", async () => {
  const harness = makeHarness({ trust: "github:valid\ninvalid\n" })
  await assert.rejects(() => run(harness))
  assert.deepEqual(harness.calls.reviews, [])
  assert.deepEqual(harness.calls.updates, [])
})

test("API failures fail without commenting on or closing the pull request", async () => {
  const harness = makeHarness()
  harness.github.rest.repos.getContent = async () => {
    throw Object.assign(new Error("unavailable"), { status: 503 })
  }
  await assert.rejects(() => run(harness))
  assert.deepEqual(harness.calls.reviews, [])
  assert.deepEqual(harness.calls.updates, [])
})

test("a failed guidance comment does not close the pull request", async () => {
  const harness = makeHarness()
  harness.github.rest.pulls.createReview = async () => {
    throw Object.assign(new Error("forbidden"), { status: 403 })
  }
  await assert.rejects(() => run(harness))
  assert.deepEqual(harness.calls.updates, [])
})
