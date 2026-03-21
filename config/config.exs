import Config

# Use EXLA for JIT-compiled pooling/normalization in Pipeline.mean_pool_and_normalize/2
config :nx, default_defn_options: [compiler: EXLA]

# Semantic versioning via conventional commits
config :git_ops,
  mix_project: ExEmbed.MixProject,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/dmcbane/ex_embed",
  types: [
    feat: [header: "New Features", hidden?: false],
    fix: [header: "Bug Fixes", hidden?: false],
    refactor: [header: "Refactoring", hidden?: false],
    security: [header: "Security", hidden?: false],
    perf: [header: "Performance", hidden?: false],
    test: [header: "Tests", hidden?: true],
    chore: [header: "Chores", hidden?: true]
  ],
  manage_mix_version?: true,
  manage_readme_version: false,
  version_tag_prefix: "v"
