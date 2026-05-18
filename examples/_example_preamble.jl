# Shared setup for EnvCGE examples.
# Lets examples run from any working directory with either:
#   julia --project=. examples/read_excel_data.jl
# or:
#   julia examples/read_excel_data.jl

import Pkg
const ENV_CGE_PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ENV_CGE_PROJECT_ROOT; io=devnull)

example_path(path::AbstractString) = isabspath(path) ? normpath(path) : normpath(joinpath(ENV_CGE_PROJECT_ROOT, path))
