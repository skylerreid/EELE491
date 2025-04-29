#skyler reid
#integrate GIC solution with plotting tool
#run decoupled power flow simulation, extract and plot reactive power loss at bus locations
#created 3/5/25 for EELE 491

#figure out if buses in memphis area are slack
#determine relationship between loads and qloss calc
#formulation, constraints tied to loads

using PowerModelsGMD, PowerModels, Shapefile, Plots, DataFrames, ColorSchemes, Ipopt, JuMP

#outline square around shelby county, TN
shelby_cty_latmin = 34.989
shelby_cty_latmax = 35.418
shelby_cty_longmin = -90.3
shelby_cty_longmax = -89.6

#load network case supplied by LANL (change number at end for different field strength, 1, 2, 5, 10 available)
PowerModels.silence()
network_case = PowerModelsGMD.parse_file("C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m")
data = network_case

#----------adjust load values for buses in region------------------
adjusted_buses = String[]
for (bus_num, bus_data) in network_case["bus"]
    lat = bus_data["lat"]
    lon = bus_data["lon"]

    if shelby_cty_latmin <= lat <= shelby_cty_latmax && shelby_cty_longmin <= lon <= shelby_cty_longmax
        if haskey(network_case["load"], bus_num)
            bus_load = network_case["load"][bus_num]
            bus_load["pd"] *= 0.9
            bus_load["qd"] *= 0.9
            push!(adjusted_buses, bus_num)
        end
    end
end

println("Loads adjusted at buses: ", adjusted_buses)  # print adjusted buses

#------figure out which buses are gens----------------
gens_list = []
for gen_id in keys(network_case["gen"]) 
    push!(gens_list, network_case["gen"][gen_id]["gen_bus"])
end
#----------extract coords for gens----------
gens_lats = Float32[]
gens_lons = Float32[]
for (bus_number, bus_info) in network_case["bus"] # loop through key-value pairs
    # Check if this bus number is associated with a generator
    for (gen_id, gen_info) in network_case["gen"]
        if string(gen_info["gen_bus"]) == bus_number # bus numbers compared as strings
            lat = bus_info["lat"]
            lon = bus_info["lon"]
            push!(gens_lats, lat)
            push!(gens_lons, lon)
            break # move on to next generator
        end
    end
end
println("Generators connected to buses: ", gens_list)  # print generator buses

#----------extract lines from branch data (to and from vectors)----------                     
froms = Int32[]
tos = Int32[]
#line i goes from froms[i] to tos[i]
for (branch_id, branch_info) in network_case["branch"]
    # Check if the branch is a transformer
    if !branch_info["transformer"]
        from_bus = branch_info["f_bus"]
        to_bus = branch_info["t_bus"]
        push!(froms, from_bus)
        push!(tos, to_bus)
    end
end

#configure local setting for GIC solver
setting = Dict{String,Any}("output" => Dict{String,Any}("branch_flows" => true))
local_setting = Dict{String,Any}("bound_voltage" => true)
        merge!(local_setting, setting)

#----------CONFIGURE SOLVER, RUN ---------------------------------------------------------
solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
PowerModelsGMD.silence() # don't print 500 lines of warnings to console
result = PowerModelsGMD.solve_gmd_decoupled(network_case, PowerModels.ACPPowerModel, solver, PowerModelsGMD.solve_gmd, PowerModelsGMD.solve_gmd_pf; setting=local_setting)

# arrays for lat, long, qloss
latitudes = Float32[]
longitudes = Float32[]
failures_q = Float32[]

# Extract qloss values
qloss_dict = result["solution"]["qloss"]
bus_numbers = String[]
bus_coords = Dict{String, Tuple{Float64, Float64}}()

# extract lat, long, qloss
# qloss_dict contains empty dicts, keys contain data (weird)
for (k, bus_data) in data["bus"]
    lat = bus_data["lat"]
    lon = bus_data["lon"]
    bus_coords[k] = (lat, lon) # Store coordinates to plot transmission lines later

    if haskey(qloss_dict, k)
        qloss_val = tryparse(Float32, k)  # convert the string key to a number
        if qloss_val !== nothing && qloss_val > 0
            push!(latitudes, lat)
            push!(longitudes, lon)
            push!(failures_q, qloss_val)
            push!(bus_numbers, k)
        end
    end
end

#------------BEGIN ALL PLOTTING --------------------------------
# load table containing state outlines and convert to dataframe
shp = Shapefile.Table("C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\data\\ne_110m_admin_1_states_provinces.shp")
df = DataFrame(shp)
# extract map data for state. Edit state name in red. Shape contained in geometry field
tennessee = filter(row -> row.name == "Tennessee", df)
p1 = plot(aspect_ratio=:equal, size = (1200, 500))  # set equal to avoid weird scaling issue
for geom in tennessee.geometry
    plot!(p1, geom, color=:lightgray, lw=1, label=false)
end

scatter!(p1, longitudes, latitudes, marker_z=failures_q, 
         markersize=3, colorbar=true, 
         palette=:viridis, label="Reactive Power Loss", 
         title="Reactive Power Loss in Tennessee Synthetic Grid")

         for i in 1:(length(froms))
            from_bus = string(froms[i]) # swap int to str to make comparison easier
            to_bus = string(tos[i])     
        
            if haskey(bus_coords, from_bus) && haskey(bus_coords, to_bus)
                from_lat, from_lon = bus_coords[from_bus]
                to_lat, to_lon = bus_coords[to_bus]
        
                plot!(p1, [from_lon, to_lon], [from_lat, to_lat],
                      color=:black, linewidth=0.5, label="") # Label set to "" to avoid multiple entries in legend
            else
                println("Warning: Could not find coordinates for bus(es) in froms[$i] ($(from_bus)) or tos[$i] ($(to_bus)).")
            end
        end

# Loop through froms and tos to plot lines (new plot)
p2 = plot(aspect_ratio=:equal, title="Transmission Lines and Generators", size=(1200, 500))
for geom in tennessee.geometry
    plot!(p2, geom, color=:lightgray, lw=1, label=false)
end
for i in 1:(length(froms))
    from_bus = string(froms[i]) # swap int to str to make comparison easier
    to_bus = string(tos[i])     

    if haskey(bus_coords, from_bus) && haskey(bus_coords, to_bus)
        from_lat, from_lon = bus_coords[from_bus]
        to_lat, to_lon = bus_coords[to_bus]

        plot!(p2, [from_lon, to_lon], [from_lat, to_lat],
              color=:blue, linewidth=1, label="") # Label set to "" to avoid multiple entries in legend
    else
        println("Warning: Could not find coordinates for bus(es) in froms[$i] ($(from_bus)) or tos[$i] ($(to_bus)).")
    end
end
#add gens to plots
scatter!(p1, gens_lons, gens_lats, markersize=5, color=:blue, label="Generators")    
scatter!(p2, gens_lons, gens_lats, markersize=5, color=:red, label="Generators")

plot!(p2, [shelby_cty_longmin, shelby_cty_longmax, shelby_cty_longmax, shelby_cty_longmin, shelby_cty_longmin], 
      [shelby_cty_latmin, shelby_cty_latmin, shelby_cty_latmax, shelby_cty_latmax, shelby_cty_latmin], 
      color=:green, linewidth=2, label="Shelby County Area", linestyle=:dash)

plot!(p1, [shelby_cty_longmin, shelby_cty_longmax, shelby_cty_longmax, shelby_cty_longmin, shelby_cty_longmin], 
      [shelby_cty_latmin, shelby_cty_latmin, shelby_cty_latmax, shelby_cty_latmax, shelby_cty_latmin], 
      color=:green, linewidth=2, label="Shelby County Area", linestyle=:dash)

display(p1)
display(p2)