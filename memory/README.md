# Memory

Store durable guidance and non-derivable context here. Use
[docs](../docs/README.md) for intentional designs and research, and the
project's task tracker for TODOs and implementation progress.

Search before writing. Update a related page instead of duplicating it.
Do not record session logs, recent Git history, or facts the current source
already explains. Pages are searched when needed, not loaded in bulk.

## Page format

Ordinary pages use this frontmatter, with one chosen type:

```yaml
---
name: example-name
description: A short summary of the guidance and when it applies.
type: reference
---
```

The name must match the filename without `.md`, using lowercase words
separated by hyphens. Types are `user` for preferences, `feedback` for
corrections, `project` for incident or investigation context, and `reference`
for validated lessons or external references. Only `project` pages have a
`status`, which must be `active` outside the archive or `resolved` inside it.

Frontmatter supports only these named fields and one-line string values.
Use plain text, JSON-style double quotes, or YAML single quotes. Arrays,
nested objects, multiline values, and YAML tags are unsupported. The checker
reports them instead of silently ignoring them.

Start with a clear title and a short summary. For feedback and incidents,
explain the rule, why it matters, and how to apply it. Include evidence and
absolute dates for changing external facts when useful. Recheck those facts
when related work depends on them. Do not invent a verification date.

## Page organization

Keep each page focused on one topic. Review a long page before adding more;
split independent topics into linked pages when that improves reading and
maintenance. Preserve the rule, reason, and evidence together. Follow the
[Markdown guidance](../docs/development-workflow.md#markdown-pages).

## Index and archive

Link every active page from the index below. A large section can have its
own `README.md` index linked from this one. Keep filenames and links current.
Move obsolete notes to `archive/`; resolved incidents use `status: resolved`.
Remove archived pages from active indexes. Their source files remain in Git,
but QMD excludes them. Create archive directories only when needed.

PR review records in `pr_reviews/` retain their owning review tool's format.
They are excluded from QMD and these document checks. Do not create empty
review records or convert them into ordinary memory pages.

## Active pages

Add links as durable knowledge is established. Do not seed invented memories.
