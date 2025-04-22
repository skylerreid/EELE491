using PowerModels
using MathOptInterface

include("modify_gens.jl")


# Finds the lower bound of reactive power (Qg) for specified generators
# before the power flow solution fails.  Uses a bisection search.

# function assumes that the input case solves with the default reactive power levels


function find_qg_limit(case::Dict, gen_indices::Vector{Int}, tolerance::Float64)
    # Configure local setting for GIC solver
    setting = Dict{String,Any}("output" => Dict{String,Any}("branch_flows" => true))
    local_setting = Dict{String,Any}("bound_voltage" => true)
    merge!(local_setting, setting)
    solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
    # Define the power flow function
    function power_flow_tf(pm_case::Dict) #wrap the power flow
        result = solve_ac_opf(pm_case, solver)
        if haskey(result, "termination_status") && result["termination_status"] == MathOptInterface.LOCALLY_SOLVED
            return true
        else
            return false
        end
    end

    results = Dict{Int,Union{Float64,String}}() # Store the result, can be a float or a string

    qg_mult_low = 0.0
    qg_mult_high = 1.0
    iters = 0

    # Check if the power flow solves with zero reactive power
    temp_case_zero_qg = deepcopy(case)
    modify_gens(temp_case_zero_qg, gen_indices, 1.0, 0.0)        #call modify_gens function (found in this repo)
    if gmd_power_flow(temp_case_zero_qg)
        println("Power flow solves with zero reactive power for the specified generators. No lower limit found.")
        for gen_index in gen_indices
            results[gen_index] = "no lower limit"
        end
        return results
    end

    while (qg_mult_high - qg_mult_low) > tolerance        #bracket search 
        qg_mult_mid = (qg_mult_low + qg_mult_high) / 2.0
        temp_case = deepcopy(case) # Create copy of the case. potentially unnecessary malloc, not sure how to avoid for now
        modify_gens(temp_case, gen_indices, 1.0, qg_mult_mid)
        iters = iters + 1
        if gmd_power_flow(temp_case)
            # If power flow is successful, update lower bound
            qg_mult_high = qg_mult_mid
        else
            # If power flow fails, update upper bound
            qg_mult_low = qg_mult_mid
        end
    end

    # Store the final lower limit multiplier for all specified generators
    for gen_index in gen_indices
        results[gen_index] = qg_mult_low
    end

    if isempty(results) && !isempty(gen_indices)
        println("Bracketing failed to find a lower limit for the combined Qg of the specified generators.")
    end
    println("Solution found after $iters bracketing iterations")
    return results
end
