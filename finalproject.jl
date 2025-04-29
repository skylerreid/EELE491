using PowerModels, PowerModelsGMD, JuMP, Ipopt, Plots, ColorSchemes, Shapefile, DataFrames, Statistics

include("find_qg_limit.jl")
include("modify_gens.jl")
include("loadtogenratio.jl")
include("modify_loads.jl")
include("state_plot.jl")

#run this with gmd opf instead of MLD
PowerModelsGMD.silence()

case_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m"
solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
#configure local setting for GIC solver
setting = Dict{String,Any}("output" => Dict{String,Any}("branch_flows" => true))
local_setting = Dict{String,Any}("bound_voltage" => true)
        merge!(local_setting, setting)

case1 = PowerModelsGMD.parse_file(case_path)
q_lim = find_qg_limit(case1, [1,2,3,4,5,6,7,8,9,10,11,12,13,14], 0.01)      #operating on first half of gens

modify_gens(case1, [1,2,3,4,5,6,7,8,9,10,11,12,13,14], 1.0, q_lim) #modify generators
ratio = loadtogenratio(case1) #load to gen ratio

result_base = solve_ac_opf(case1,solver)
result_gmd = PowerModelsGMD.solve_gmd_decoupled(case1, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)
println("L2G ratio before modifying loads: $ratio")
modify_loads(case1, 34.989, 35.418, -90.3, -89.6, 0.8) #modify loads
result_mod = PowerModelsGMD.solve_gmd_decoupled(case1, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)
ratio2 = loadtogenratio(case1)
println("L2G ratio after modifying loads: $ratio2")

#extract voltage data from results
v_results_base = Float32[]
v_results_gmd = Float32[]
v_results_mod = Float32[]

for (bus_num, bus_data) in result_base["solution"]["bus"]
        push!(v_results_base, bus_data["vm"])
    end
for (bus_num, bus_data) in result_gmd["solution"]["bus"]
        push!(v_results_gmd, bus_data["vm"])
end
for (bus_num, bus_data) in result_mod["solution"]["bus"]
        push!(v_results_mod, bus_data["vm"])
end

voltage_diff21 = v_results_gmd .- v_results_base
voltage_diff32 = v_results_mod .- v_results_base

bus_lats = Float32[]
bus_lons = Float32[]

for (bus_number, bus_info) in case1["bus"] # extract lat/long of buses from case
    lat = bus_info["lat"]
    lon = bus_info["lon"]
    push!(bus_lats, lat)
    push!(bus_lons, lon)
end

p1 = state_plot("TN", 1200, 500, "Change in Voltage Magnitude (Base OPF to GMD case)")
p2 = state_plot("TN", 1200, 500, "Change in Voltage Magnitude (GMD case with modified loads)")

# Create a scatter plot of the bus locations
scatter!(p1, bus_lons, bus_lats, marker_z=voltage_diff21, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Voltage Magnitude (per unit)")
scatter!(p2, bus_lons, bus_lats, marker_z=voltage_diff32, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Voltage Magnitude (per unit)")

display(p1)
display(p2)

adjusted_buses = [66,71,74,75,76,77,78,79,80,81,82]
vm_base = Float32[]
va_base = Float32[]
vm_gmd = Float32[]
va_gmd = Float32[]
vm_mod = Float32[]
va_mod = Float32[]

# extract relevant mags and angles from base case
for bus_num in adjusted_buses
        bus_key = string(bus_num)
        if haskey(result_base["solution"]["bus"], bus_key)
            push!(vm_base, result_base["solution"]["bus"][bus_key]["vm"])
            push!(va_base, result_base["solution"]["bus"][bus_key]["va"])
        else
            push!(vm_base, NaN) # nan to array if missing to preserve indexing
            push!(va_base, NaN)
        end
    end

# extract relevant mags and angles from gmd case
for bus_num in adjusted_buses
        bus_key = string(bus_num)
        if haskey(result_gmd["solution"]["bus"], bus_key)
            push!(vm_gmd, result_gmd["solution"]["bus"][bus_key]["vm"])
            push!(va_gmd, result_gmd["solution"]["bus"][bus_key]["va"])
        else
            push!(vm_gmd, NaN)
            push!(va_gmd, NaN)
        end
    end

# extract relevant mags and angles from gmd case w/ modded loads
for bus_num in adjusted_buses
        bus_key = string(bus_num)
        if haskey(result_mod["solution"]["bus"], bus_key)
            push!(vm_mod, result_mod["solution"]["bus"][bus_key]["vm"])
            push!(va_mod, result_mod["solution"]["bus"][bus_key]["va"])
        else
            push!(vm_mod, NaN)
            push!(va_mod, NaN)
        end
    end

df_voltages = DataFrame(
        Bus = adjusted_buses,
        VM_Base = vm_base,
        VA_Base = va_base,
        VM_GMD = vm_gmd,
        VA_GMD = va_gmd,
        VM_Mod = vm_mod,
        VA_Mod = va_mod
    )

mag_means = [mean(df_voltages.VM_Base) mean(df_voltages.VM_GMD) mean(df_voltages.VM_Mod)]
angle_means = [mean(df_voltages.VA_Base) mean(df_voltages.VA_GMD) mean(df_voltages.VA_Mod)]
    
println("Magnitude means (base, GMD, GMD with adjusted loads): $mag_means")
println("Angle means (base, GMD, GMD with adjusted loads): $angle_means")

#look at buses in this area. make table, show improvements before and after
#look at voltage angles, see if anything interesting there

#show subset/plot, explain benefit of adding local generation for GMD susceptibility
#explain what does and doesn't work in PMGMD
#new functions and what they does