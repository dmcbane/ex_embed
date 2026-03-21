import Config

# Use EXLA for JIT-compiled pooling/normalization in Pipeline.mean_pool_and_normalize/2
config :nx, default_defn_options: [compiler: EXLA]
