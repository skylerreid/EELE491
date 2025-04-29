#skyler reid
#examine the effect of modifying loads at local buses on voltage profile
#already determined that effects on Qloss are negligible or zero

#run powermodels opf, compare voltages w/o load mod

using PowerModelsGMD, PowerModels, Shapefile, Plots, DataFrames, ColorSchemes, Ipopt, JuMP, Statistics

include("state_plot.jl")
include("modify_loads.jl")
include("GTmap.jl")

shp_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\data\\ne_110m_admin_1_states_provinces.shp"

#outline square around shelby county, TN
shelby_cty_latmin = 34.989
shelby_cty_latmax = 35.418
shelby_cty_longmin = -90.3
shelby_cty_longmax = -89.6

PowerModels.silence()
case1 = PowerModelsGMD.parse_file("C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m")

#---------run first iteration of solver with no load modification---------------------
#configure local setting for GIC solver
setting = Dict{String,Any}("output" => Dict{String,Any}("branch_flows" => true))
local_setting = Dict{String,Any}("bound_voltage" => true)
        merge!(local_setting, setting)

#----------run solver on first case ---------------------------------------------------------
solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
PowerModelsGMD.silence() # don't print 500 lines of warnings to console
result1 = PowerModelsGMD.solve_gmd_decoupled(case1, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)

#load the case in again, modify loads, and run the solver again
case2 = PowerModelsGMD.parse_file("C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m")
modify_loads(case2, shelby_cty_latmin, shelby_cty_latmax, shelby_cty_longmin, shelby_cty_longmax, 0.9) 

#---------run solver again with modified loads--------------
result2 = PowerModelsGMD.solve_gmd_decoupled(case2, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)

#extract voltage data from results
v_results_1 = Float32[]
v_results_2 = Float32[]
for (bus_num, bus_data) in result1["solution"]["bus"]
    push!(v_results_1, bus_data["vm"])
end

for (bus_num, bus_data) in result2["solution"]["bus"]
    push!(v_results_2, bus_data["vm"])
end

voltage_diff = v_results_2 .- v_results_1
mean_voltage_diff = mean(voltage_diff)

#note, I wrote this function and it works for all states
p1 = state_plot("Tennessee", 1200, 500, "Change in Voltage Magnitude when Loads are Reduced", "Longitude", "Latitude")

bus_lats = Float32[]
bus_lons = Float32[]

for (bus_number, bus_info) in case1["bus"] # extract lat/long of buses from case
    lat = bus_info["lat"]
    lon = bus_info["lon"]
    push!(bus_lats, lat)
    push!(bus_lons, lon)
end
# Create a scatter plot of the bus locations
scatter!(p1, bus_lons, bus_lats, marker_z=voltage_diff, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Change in Voltage Magnitude")

p2 = GTmap("Tennessee", case1, shp_path, 1200, 500, "Generators and Transmission Lines in Tennessee Synthetic Grid")    

display(p1)
display(p2)