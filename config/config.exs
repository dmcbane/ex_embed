import Config

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

# Optional: EXLA acceleration for defn-compiled pooling/normalization.
# Users of this library should add this to their own config if desired:
#
#   config :nx, default_defn_options: [compiler: EXLA]
#
# For ExEmbed development, we enable it here:
if config_env() in [:dev, :test] do
  config :nx, default_defn_options: [compiler: EXLA]
end
