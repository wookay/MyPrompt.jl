module test_myprompt_replcompletions

using Test
using MyPrompt
using REPL.REPLCompletions # completion_text

# code from julia/stdlib/REPL/test/replcompletions.jl
function map_completion_text(completions)
    c, r, res = completions
    return map(completion_text, c), r, res
end

module CompletionFoo
end

test_complete_context(s) =  map_completion_text(completions(s,lastindex(s), CompletionFoo))

let s = "typeof(+)."
    c, r = test_complete_context(s)
    @test !isempty(c)
end

end # module test_myprompt_replcompletions
