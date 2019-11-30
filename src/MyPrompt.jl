module MyPrompt

using REPL
using .REPL.LineEdit
using .REPL: AnyDict, edit_insert, JL_PROMPT_PASTE, JULIA_PROMPT, raw!, disable_bracketed_paste, enable_bracketed_paste
using Base: GIT_VERSION_INFO, TAGGED_RELEASE_BANNER

function my_banner(io, block)
    Base.JLOptions().banner == 0 && block(io)
end

function my_prompt(repl, promptstr)
    # code from https://github.com/JuliaLang/julia/blob/master/stdlib/REPL/src/REPL.jl#L900
    extra_keymap = AnyDict(
        # Bracketed Paste Mode
        "\e[200~" => (s,o...)->begin
            input = LineEdit.bracketed_paste(s) # read directly from s until reaching the end-bracketed-paste marker
            sbuffer = LineEdit.buffer(s)
            curspos = position(sbuffer)
            seek(sbuffer, 0)
            shouldeval = (bytesavailable(sbuffer) == curspos && !occursin(UInt8('\n'), sbuffer))
            seek(sbuffer, curspos)
            if curspos == 0
                # if pasting at the beginning, strip leading whitespace
                input = lstrip(input)
            end
            if !shouldeval
                # when pasting in the middle of input, just paste in place
                # don't try to execute all the WIP, since that's rather confusing
                # and is often ill-defined how it should behave
                edit_insert(s, input)
                return
            end
            LineEdit.push_undo(s)
            edit_insert(sbuffer, input)
            input = String(take!(sbuffer))
            oldpos = firstindex(input)
            firstline = true
            isprompt_paste = false
            while oldpos <= lastindex(input) # loop until all lines have been executed
                jl_prompt_len = nothing
                if JL_PROMPT_PASTE[]
                    # Check if the next statement starts with "julia> ", in that case
                    # skip it. But first skip whitespace
                    while input[oldpos] in ('\n', ' ', '\t')
                        oldpos = nextind(input, oldpos)
                        oldpos >= sizeof(input) && return
                    end
                    # Check if input line starts with "julia> ", remove it if we are in prompt paste mode
                    if (firstline || isprompt_paste) && (startswith(SubString(input, oldpos), JULIA_PROMPT) ||
                                                         startswith(SubString(input, oldpos), promptstr))
                        if startswith(SubString(input, oldpos), JULIA_PROMPT)
                            jl_prompt_len = length(JULIA_PROMPT)
                        elseif startswith(SubString(input, oldpos), promptstr)
                            w = textwidth(promptstr)
                            jl_prompt_len = w + w - length(promptstr)
                        end
                        isprompt_paste = true
                        oldpos += jl_prompt_len
                    # If we are prompt pasting and current statement does not begin with julia> , skip to next line
                    elseif isprompt_paste
                        while input[oldpos] != '\n'
                            oldpos = nextind(input, oldpos)
                            oldpos >= sizeof(input) && return
                        end
                        continue
                    end
                end
                ast, pos = Meta.parse(input, oldpos, raise=false, depwarn=false)
                if (isa(ast, Expr) && (ast.head == :error || ast.head == :continue || ast.head == :incomplete)) ||
                        (pos > ncodeunits(input) && !endswith(input, '\n'))
                    # remaining text is incomplete (an error, or parser ran to the end but didn't stop with a newline):
                    # Insert all the remaining text as one line (might be empty)
                    tail = input[oldpos:end]
                    if !firstline
                        # strip leading whitespace, but only if it was the result of executing something
                        # (avoids modifying the user's current leading wip line)
                        tail = lstrip(tail)
                    end
                    if isprompt_paste # remove indentation spaces corresponding to the prompt
                        tail = replace(tail, Regex("^ {$jl_prompt_len}", "m") => "") # 7: jl_prompt_len
                    end
                    LineEdit.replace_line(s, tail, true)
                    LineEdit.refresh_line(s)
                    break
                end
                # get the line and strip leading and trailing whitespace
                line = strip(input[oldpos:prevind(input, pos)])
                if !isempty(line)
                    if isprompt_paste # remove indentation spaces corresponding to the prompt
                        line = replace(line, Regex("^ {$jl_prompt_len}", "m") => "") # 7: jl_prompt_len
                    end
                    # put the line on the screen and history
                    LineEdit.replace_line(s, line)
                    LineEdit.commit_line(s)
                    # execute the statement
                    terminal = LineEdit.terminal(s) # This is slightly ugly but ok for now
                    raw!(terminal, false) && disable_bracketed_paste(terminal)
                    LineEdit.mode(s).on_done(s, LineEdit.buffer(s), true)
                    raw!(terminal, true) && enable_bracketed_paste(terminal)
                    LineEdit.push_undo(s) # when the last line is incomplete
                end
                oldpos = pos
                firstline = false
            end
        end,
    )
    repl.interface = REPL.setup_interface(repl, extra_repl_keymap=extra_keymap)
    repl.interface.modes[1].prompt =  () -> begin
        promptstr
    end
end # function my_prompt()

function print_banner(io)
    # code from https://github.com/JuliaLang/julia/blob/master/base/version.jl#L262
    if GIT_VERSION_INFO.tagged_commit
        commit_string = TAGGED_RELEASE_BANNER
    elseif isempty(GIT_VERSION_INFO.commit)
        commit_string = ""
    else
        days = Int(floor((ccall(:jl_clock_now, Float64, ()) - GIT_VERSION_INFO.fork_master_timestamp) / (60 * 60 * 24)))
        days = max(0, days)
        unit = days == 1 ? "day" : "days"
        distance = GIT_VERSION_INFO.fork_master_distance
        commit = GIT_VERSION_INFO.commit_short

        if distance == 0
            commit_string = "Commit $(commit) ($(days) $(unit) old master)"
        else
            branch = GIT_VERSION_INFO.branch
            commit_string = "$(branch)/$(commit) (fork: $(distance) commits, $(days) $(unit))"
        end
    end
    commit_date = isempty(Base.GIT_VERSION_INFO.date_string) ? "" : " ($(split(Base.GIT_VERSION_INFO.date_string)[1]))"
    c = Base.text_colors
    tx = c[:normal] # text
    jl = c[:normal] # julia
    d1 = c[:bold] * c[:blue]    # first dot
    d2 = c[:bold] * c[:red]     # second dot
    d3 = c[:bold] * c[:green]   # third dot
    d4 = c[:bold] * c[:magenta] # fourth dot
    io = stdout
    print(io,"""               $(d3)_$(tx)
       $(d1)_$(tx)       $(jl)_$(tx) $(d2)_$(d3)(_)$(d4)_$(tx)     |  A fresh approach to technical computing
      $(d1)(_)$(jl)     | $(d2)(_)$(tx) $(d4)(_)$(tx)    |  Documentation: https://docs.julialang.org
       $(jl)_ _   _| |_  __ _$(tx)   |  Type \"?\" for help, \"]?\" for Pkg help.
      $(jl)| | | | | | |/ _` |$(tx)  |
      $(jl)| | |_| | | | (_| |$(tx)  |  Version $(VERSION)$(commit_date)
     $(jl)_/ |\\__'_|_|_|\\__'_|$(tx)  |  $(commit_string)
    $(jl)|__/$(tx)                   |

    """)
end


# Julia issue #32558

using .REPL.REPLCompletions: Completion, PropertyCompletion, FieldCompletion, non_identifier_chars, get_value, get_type, filtered_mod_names

# REPL Symbol Completions
# code from julia/stdlib/REPL/src/REPLCompletions.jl
function REPL.REPLCompletions.complete_symbol(sym::String, ffunc, context_module=Main)::Vector{Completion}
    mod = context_module
    name = sym

    lookup_module = true
    t = Union{}
    val = nothing
    if something(findlast(in(non_identifier_chars), sym), 0) < something(findlast(isequal('.'), sym), 0)
        # Find module
        lookup_name, name = rsplit(sym, ".", limit=2)

        ex = Meta.parse(lookup_name, raise=false, depwarn=false)

        b, found = get_value(ex, context_module)
        if found
            val = b
            if isa(b, Module)
                mod = b
                lookup_module = true
            elseif Base.isstructtype(typeof(b))
                lookup_module = false
                t = typeof(b)
            end
        else # If the value is not found using get_value, the expression contain an advanced expression
            lookup_module = false
            t, found = get_type(ex, context_module)
        end
        found || return Completion[]
        # Ensure REPLCompletion do not crash when asked to complete a tuple, #15329
        !lookup_module && t <: Tuple && return Completion[]
    end

    suggestions = Completion[]
    if lookup_module
        # We will exclude the results that the user does not want, as well
        # as excluding Main.Main.Main, etc., because that's most likely not what
        # the user wants
        p = s->(!Base.isdeprecated(mod, s) && s != nameof(mod) && ffunc(mod, s))
        # Looking for a binding in a module
        if mod == context_module
            # Also look in modules we got through `using`
            mods = ccall(:jl_module_usings, Any, (Any,), context_module)
            for m in mods
                append!(suggestions, filtered_mod_names(p, m, name))
            end
            append!(suggestions, filtered_mod_names(p, mod, name, true, true))
        else
            append!(suggestions, filtered_mod_names(p, mod, name, true, false))
        end
    elseif val !== nothing # looking for a property of an instance
        for property in propertynames(val, false)
            s = string(property)
            if startswith(s, name)
                push!(suggestions, PropertyCompletion(val, property))
            end
        end
    else
        # Looking for a member of a type
        if t isa DataType && t != Any
            local type_t(::Type{T}) where T = typeof(T)
            local type_t(x::Any)            = x
            t2 = type_t(t)
            isconcretetype(t2) && for field in fieldnames(t2)
                s = string(field)
                if startswith(s, name)
                    push!(suggestions, FieldCompletion(t2, field))
                end
            end
        end
    end
    suggestions
end

end # module
