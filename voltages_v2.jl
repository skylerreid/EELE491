#skyler reid
#run powermodels opf, compare voltages to PMGMD w/o load mod, with load mod

using PowerModels, PowerModelsGMD, Plots, Ipopt, JuMP, Statistics, Shapefile, DataFrames, ColorSchemes
PowerModels.silence()
PowerModelsGMD.silence()

include("state_plot.jl")
include("modify_loads.jl")
include("modify_gens.jl")
case_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m"
shp_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\data\\ne_110m_admin_1_states_provinces.shp"

#outline square around shelby county, TN
shelby_cty_latmin = 34.989
shelby_cty_latmax = 35.418
shelby_cty_longmin = -90.3
shelby_cty_longmax = -89.6

to_adjust = [1,3,5,7,9,11]  #list of generators to adjust using modify_gens function

#configure local setting for GIC solver
setting = Dict{String,Any}("output" => Dict{String,Any}("branch_flows" => true))
local_setting = Dict{String,Any}("bound_voltage" => true)
        merge!(local_setting, setting)

case1 = PowerModelsGMD.parse_file(case_path)

solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
#solve normal AC OPF using powermodels
result1 = solve_ac_opf(case1, solver)
#solve GMD decoupled 
result2 = PowerModelsGMD.solve_gmd_decoupled(case1, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)

#modify loads, run solver again
case3 = PowerModelsGMD.parse_file(case_path)
modify_gens(case3, to_adjust, 1.0, 0.9) #modify generators
#modify_loads(case3, shelby_cty_latmin, shelby_cty_latmax, shelby_cty_longmin, shelby_cty_longmax, 0.9)
result3 = PowerModelsGMD.solve_gmd_decoupled(case3, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)

#extract voltage data from results
v_results_1 = Float32[]
v_results_2 = Float32[]
v_results_3 = Float32[]
for (bus_num, bus_data) in result1["solution"]["bus"]
    push!(v_results_1, bus_data["vm"])
end
for (bus_num, bus_data) in result2["solution"]["bus"]
    push!(v_results_2, bus_data["vm"])
end

voltage_diff21 = v_results_2 .- v_results_1
voltage_diff32 = v_results_3 .- v_results_2

p1 = state_plot("TN", 1200, 500, "Change in Voltage Magnitude from no GMD to yes GMD")
p2 = state_plot("TN", 1200, 500, "Change in Voltage Magnitude from no GMD to GMD with load mod")

bus_lats = Float32[]
bus_lons = Float32[]

for (bus_number, bus_info) in case1["bus"] # extract lat/long of buses from case
    lat = bus_info["lat"]
    lon = bus_info["lon"]
    push!(bus_lats, lat)
    push!(bus_lons, lon)
end
# Create a scatter plot of the bus locations
scatter!(p1, bus_lons, bus_lats, marker_z=voltage_diff21, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Change in Voltage Magnitude (per unit)")

# Create a scatter plot of the bus locations
scatter!(p2, bus_lons, bus_lats, marker_z=voltage_diff32, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Change in Voltage Magnitude (per unit)")

display(p1)
display(p2)