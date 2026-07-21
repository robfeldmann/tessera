"use strict"

const { TextDecoder } = require("node:util")

const MAX_VOUCHED_BYTES = 64 * 1024
const TRUST_PATH = ".github/VOUCHED.td"
const ALLOWED_BOTS = new Set(["dependabot[bot]"])
const MAINTAINER_PERMISSIONS = new Set(["admin", "maintain", "write"])
const ENTRY_PATTERN = /^(-)?github:([A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?)$/

function parseVouched(text) {
  if (typeof text !== "string") {
    throw new TypeError("VOUCHED.td must decode to text")
  }
  if (Buffer.byteLength(text, "utf8") > MAX_VOUCHED_BYTES) {
    throw new Error(`VOUCHED.td exceeds ${MAX_VOUCHED_BYTES} bytes`)
  }

  const normalized = text.replaceAll("\r\n", "\n")
  if (normalized.includes("\r")) {
    throw new Error("VOUCHED.td contains an unsupported carriage return")
  }

  const entries = new Map()
  for (const [index, sourceLine] of normalized.split("\n").entries()) {
    const line = sourceLine.trim()
    if (line === "" || line.startsWith("#")) {
      continue
    }

    const match = ENTRY_PATTERN.exec(line)
    if (!match) {
      throw new Error(`Invalid VOUCHED.td entry on line ${index + 1}`)
    }

    const login = match[2].toLowerCase()
    if (entries.has(login)) {
      throw new Error(`Duplicate or conflicting VOUCHED.td entry for ${login}`)
    }
    entries.set(login, match[1] === "-" ? "denounced" : "vouched")
  }

  return entries
}

function decodeVouchedFile(data) {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data) ||
    data.type !== "file" ||
    data.encoding !== "base64" ||
    typeof data.content !== "string"
  ) {
    throw new Error(`Expected ${TRUST_PATH} to be a base64-encoded file`)
  }

  const encoded = data.content.replaceAll(/\s/g, "")
  if (
    encoded.length === 0 ||
    encoded.length % 4 !== 0 ||
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)
  ) {
    throw new Error(`${TRUST_PATH} contains invalid base64 data`)
  }

  const bytes = Buffer.from(encoded, "base64")
  if (bytes.length > MAX_VOUCHED_BYTES) {
    throw new Error(`${TRUST_PATH} exceeds ${MAX_VOUCHED_BYTES} bytes`)
  }

  return new TextDecoder("utf-8", { fatal: true }).decode(bytes)
}

function isMaintainer(permissionLevel) {
  return [permissionLevel.permission, permissionLevel.role_name].some((permission) =>
    MAINTAINER_PERMISSIONS.has(permission),
  )
}

async function collaboratorPermission(github, owner, repo, username) {
  try {
    const response = await github.rest.repos.getCollaboratorPermissionLevel({
      owner,
      repo,
      username,
    })
    return response.data
  } catch (error) {
    if (error?.status === 404) {
      return { permission: "none", role_name: "none" }
    }
    throw error
  }
}

function decisionFor({ author, permissionLevel, entries }) {
  const login = author.toLowerCase()
  if (ALLOWED_BOTS.has(login)) {
    return "automation"
  }
  if (isMaintainer(permissionLevel)) {
    return "maintainer"
  }
  return entries.get(login) ?? "unknown"
}

async function run({ github, context, core }) {
  const pullRequest = context.payload.pull_request
  const defaultBranch = context.payload.repository?.default_branch
  const author = pullRequest?.user?.login

  if (!pullRequest || typeof author !== "string" || !defaultBranch) {
    throw new Error("Expected a pull_request_target event with repository metadata")
  }

  const { owner, repo } = context.repo
  const trustResponse = await github.rest.repos.getContent({
    owner,
    repo,
    path: TRUST_PATH,
    ref: defaultBranch,
  })
  const entries = parseVouched(decodeVouchedFile(trustResponse.data))
  const permissionLevel = await collaboratorPermission(github, owner, repo, author)
  const decision = decisionFor({ author, permissionLevel, entries })

  core.setOutput("status", decision)
  if (["automation", "maintainer", "vouched"].includes(decision)) {
    core.info(`Allowing ${author}: ${decision}`)
    return decision
  }

  const body = [
    `Hi @${author}, thanks for your interest in contributing to Tessera.`,
    "",
    "Tessera currently accepts pull requests from vouched contributors after the proposed work has been discussed with the maintainer.",
    "",
    `Please start with an issue or Discussion. If the work is accepted, submit a Vouch Request at https://github.com/${owner}/${repo}/discussions/new?category=vouch-request. The maintainer can then add you through a separate, reviewed trust-list pull request. Reopen this pull request only after that update reaches the default branch.`,
    "",
    `See https://github.com/${owner}/${repo}/blob/${defaultBranch}/CONTRIBUTING.md for the full process.`,
  ].join("\n")

  await github.rest.pulls.createReview({
    owner,
    repo,
    pull_number: pullRequest.number,
    event: "COMMENT",
    body,
  })
  await github.rest.pulls.update({
    owner,
    repo,
    pull_number: pullRequest.number,
    state: "closed",
  })
  core.info(`Closed pull request from ${author}: ${decision}`)
  return decision
}

module.exports = {
  MAX_VOUCHED_BYTES,
  TRUST_PATH,
  collaboratorPermission,
  decodeVouchedFile,
  decisionFor,
  isMaintainer,
  parseVouched,
  run,
}
