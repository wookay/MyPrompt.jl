### MyPrompt.jl

|  **Build Status**                |
|:---------------------------------|
|  [![][actions-img]][actions-url] |

### banner

```julia
$ julia --banner=no -i -e 'using MyPrompt; MyPrompt.banner()'
               _
   _       _ _(_)_     |  A fresh approach to technical computing
  (_)     | (_) (_)    |  Documentation: https://docs.julialang.org
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.3.0 (2019-11-26)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/

julia> 
```

### set_prompt

```julia
$ cat .julia/config/startup.jl
using REPL: atreplinit
using MyPrompt: set_prompt

atreplinit() do repl
    set_prompt(repl, "줄리아> ")
end

$ julia --banner=no
줄리아> 
```

[actions-img]: https://github.com/wookay/MyPrompt.jl/workflows/CI/badge.svg
[actions-url]: https://github.com/wookay/MyPrompt.jl/actions
