#like the modify_loads function, this can be called inline on a case defined using the PowerModels.jl parser
#instead of specifying an area to operate over, this function works on bus numbers since there are typically far fewer gens than load buses. 
#unlike the modify_loads function, p and q can be adjusted separately

function modify_gens(case::Dict, gen_indices::Vector{Int}, p_multiplier::Float64, q_multiplier::Float64)
    println("Adjusted generators:")
    for gen_index in gen_indices
        if haskey(case["gen"], string(gen_index)) # Use string(gen_index) because keys in case["gen"] are strings
            gen_data = case["gen"][string(gen_index)]
            gen_data["pg"] *= p_multiplier
            gen_data["qg"] *= q_multiplier
            println(gen_index)
        else
            println("Generator $gen_index not found in the case data.")
        end
    end
end
