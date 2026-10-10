# Documents

Store designs, decisions, research, and reference guides here. Use
[memory](../memory/README.md) for durable guidance and non-derivable context,
[td](foundation/task-tracking.md) for local progress and handoffs, and GitHub
Issues for shared scope and acceptance criteria.

## Page format

Every ordinary document has a clear title, an opening summary, and one status
field:

```yaml
---
status: current
---
```

Use `draft` while a document is in progress, `current` for the current
reference or plan, `superseded` when another document replaces it, and
`archived` when it is no longer active. A current design does not prove it was
implemented or approved. Keep superseded and archived documents under
`archive/`, with a replacement link when one exists.

Frontmatter values are one-line strings: plain text, JSON-style double quotes,
or YAML single quotes. Only `status` is defined for ordinary docs, and README
indexes need no frontmatter. Extend the schema deliberately if needed.

## Decisions and evidence

Record each accepted decision in its authoritative document before moving to
the next interview question, with the date, the user's reason or an
established constraint, and any material tradeoff. Say when a reason is
unknown. Keep recommendations, open questions, and accepted decisions
separate; silence is not approval. Keep each decision in one place, link to it
elsewhere, and explain what supersedes it when it changes.

Give changing external facts a source and verification date when useful, and
review them when related work depends on them. Do not store interview
transcripts or task checklists here.

## Organization and links

Follow the [Markdown guidance](foundation/engineering-policy.md#markdown-pages).
Keep small projects flat, and add folders such as `research/` when needed.
Link every active page from this index, directly or through another README
index, and remove archived pages from active indexes. Use relative file links
and ordinary heading anchors; ATX and setext headings, duplicate heading
slugs, and explicit HTML `id` anchors are supported.

Exclude generated docs through `checks.exclude` in `.config/knowledge.json`,
and align QMD exclusions when they should not be searched. Never exempt
hand-written pages to bypass failed checks.

## Active pages

- [Project Starter foundation](foundation/README.md): shared engineering,
  knowledge search, and task tracking policy.
- [Development workflow](development-workflow.md): this project's setup,
  checks, versions, and deployment.
- [Configuration](configuration.md): providers, models, prompts, limits, and output checks.
- [Architecture](architecture.md): component responsibilities and Git behavior.
- [Release notes](releases.md): changes and upgrade requirements.
- [Local model selection](local-model-selection.md): measured latency, quality, and the selected models.
