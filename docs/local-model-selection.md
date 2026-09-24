---
status: current
---

# Local model selection

On September 24, 2026, the chosen local setup for Jubi's M5 Pro Mac with
64 GB unified memory was Gemma 4 26B-A4B for Jeeves and Qwen 3.8 27B for
larger tasks. The user preferred keeping Gemma's quality with a roughly
three-second target for a large diff. This is a selection metric, not a
generation timeout. Comparison models were removed.

| Role | Installed Ollama tag | Download size |
| --- | --- | --- |
| Default for Jeeves | `gemma4:26b-nvfp4` | 16 GB |
| Larger model | `qwen3.8:27b-mlx` | 18 GB |

Gemma is the faster option, although it is not small on disk. Its mixture
of experts architecture activates 3.8 billion parameters per token from
25.2 billion total. Google's published LiveCodeBench v6 results are 77.1%
for 26B-A4B, 52.0% for E4B, and 44.0% for E2B. These coding scores inform
the choice; they do not measure commit messages or this no-thinking setup.
See the [Google model card](https://ai.google.dev/gemma/docs/core/model_card_4).

## Local measurements

Tests used Ollama 0.34.4, a 32,768-token context, thinking disabled, and complete
non-streaming responses. Six neutral cases covered SSL verification, retry
conditions, a zero-valued fallback, account permissions, stdin handling,
and adding provider support. Two cases also exercised the sarcastic prompt.
The larger provider diff was about 11 KB; timing is not a promise for all
inputs described as large.

With the final neutral prompt, direct HTTP generation took 0.55–0.64 seconds
for the three short logic changes and 2.72 seconds for the provider diff.
The actual Jeeves command launched through interactive fish took 0.76–0.90
seconds for those short changes, 1.72 seconds for stdin support, and 2.75
seconds for the provider diff. A first request including loading took 3.66
seconds. Earlier cold runs reached 6.81 seconds. Cached repeated inputs can
be faster and should not be confused with fresh diffs.

Before the final body-length adjustment, the same provider case gave these
exploration results. Each row is an individual observation, not a statistical
latency estimate. Output length and decoding settings affect comparisons.

| Candidate | Larger diff | Main observation |
| --- | --- | --- |
| Gemma 4 26B-A4B | 2.80 s | Good behavior descriptions; strongest published Gemma coding score among these candidates |
| Gemma 4 E4B | 1.99 s | Useful faster option, with weaker commit-type choices and some inaccurate descriptions |
| Gemma 4 E2B | 0.83 s | Very fast; falsely described existing dry-run behavior as new |
| Qwen 3.5 2B | 0.67 s | Misidentified a nullish-coalescing change |
| Qwen 3.5 4B | 1.52 s | Misstated fallback and retry behavior in some cases |
| Qwen 3.5 9B | 3.57 s | Less attractive speed and quality balance than Gemma |
| Liquid LFM2.5 8B | 7.31 s | Leaked reasoning and reached the output limit |
| Liquid LFM2 24B-A2B | 1.93 s | Other cases produced inaccurate or repetitive output; a sarcastic case reached the limit |
| Qwen 3.8 27B | 10.59 s | Retained for larger tasks, too slow for the Jeeves target |

Gemma 26B still sometimes calls a behavior change a `refactor` and can omit
useful details. Its messages need the same review as other generated text.
Jeeves corrects emoji and spacing mechanically; it does not claim to validate
semantic accuracy. Sarcastic output can be longer and slower than neutral
output. The final sarcastic provider test took 4.20 seconds.

## Saved settings

Jubi's fish startup loads `~/.env`, which selects `ollama` and
`gemma4:26b-nvfp4`. The existing OpenRouter model setting is retained for
`jeeves --provider openrouter`. For another machine, choose an appropriate
installed tag; the NVFP4 and MLX packages tested here are machine-specific.
See [configuration](configuration.md) for all settings and prompt precedence.
