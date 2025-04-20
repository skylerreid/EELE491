function state_plot(State::String, height::Int, width::Int, title::String, x_label::String, y_label::String, shp_path::String="C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\data\\ne_110m_admin_1_states_provinces.shp", state_name_column::String="name")
    shp = Shapefile.Table(shp_path)
    df = DataFrame(shp)

    state_df = filter(row -> row[state_name_column] == State, df)
    p = plot(aspect_ratio=:equal, size = (height, width), title = title, xlabel = x_label, ylabel = y_label)
    for geom in state_df.geometry
        plot!(p, geom, color=:lightgray, lw=1, label=false)
    end

    return p
end