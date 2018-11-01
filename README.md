### MyPrompt

```
$ cat .julia/config/startup.jl
using REPL: atreplinit
using MyPrompt: my_banner, print_banner, my_prompt

atreplinit() do repl
    my_banner(stdout, print_banner)
    my_prompt(repl, "줄리아> ")
end
```

```
~ julia --banner=no
               _
   _       _ _(_)_     |  A fresh approach to technical computing
  (_)     | (_) (_)    |  Documentation: https://docs.julialang.org
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.1.0-DEV.597 (2018-11-01)
 _/ |\__'_|_|_|\__'_|  |  Commit f0017a4964* (0 days old master)
|__/                   |

줄리아>
```
