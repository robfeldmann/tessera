# Security Policy

Tessera is pre-1.0, under active development, and not suitable for production use.
Security reports are still welcome and help establish safer behavior before the first
public release.

## Supported versions

There is no public release yet. Security fixes target the current `main` branch. After
releases begin, the latest published release and `main` will receive best-effort security
updates; older releases and arbitrary historical revisions are unsupported.

| Version                               | Supported   |
| ------------------------------------- | ----------- |
| Current `main`                        | Best effort |
| Latest public release, once available | Best effort |
| Older releases and revisions          | No          |

## Report a vulnerability privately

Email [me@robfeldmann.com](mailto:me@robfeldmann.com?subject=Tessera%20security%20report)
with the subject **Tessera security report**. Do not open a public issue, Discussion, or
pull request containing vulnerability details.

Include only what is needed to investigate safely:

- the affected Tessera release or commit;
- the affected platform and environment;
- a description of the impact and attack conditions;
- minimal reproduction steps or a proof of concept; and
- any known mitigation or workaround.

Do not send credentials, production data, unrelated private logs, or destructive payloads.
If sensitive material is necessary, first ask how to transfer it.

## Response and disclosure

The maintainer targets an initial acknowledgment within seven calendar days and an initial
assessment within fourteen days. These are best-effort targets, not a service-level
agreement. The maintainer may request clarification, coordinate a fix and advisory, or
explain why a report is out of scope.

Keep vulnerability details private until a fix or mitigation is available and a disclosure
date has been coordinated. Tessera will credit reporters who request credit, but does not
currently operate a bug bounty or promise a particular release date.

## Scope

In scope are vulnerabilities in Tessera code on the current `main` branch or latest public
release that cross a security boundary or create a concrete confidentiality, integrity, or
availability impact.

The following are out of scope:

- ordinary bugs, crashes, incomplete APIs, or unsupported platform behavior without a
  demonstrated security impact;
- unsupported releases or historical revisions;
- vulnerabilities solely in an upstream dependency without a Tessera-specific impact;
- theoretical findings without a plausible attack path;
- social engineering, spam, denial of service against project infrastructure, or testing
  that affects other people or systems; and
- reports that require exposing credentials, personal data, or other secrets.

Use the public bug form for non-security defects and GitHub Discussions for usage or
design questions.
