function loadtogenratio(case)

    pload = 0.0
    qload = 0.0
    pgen = 0.0
    qgen = 0.0

    # sum p and q at each load bus
    for (bus_num, load_data) in case["load"]
        pload += load_data["pd"]
        qload += load_data["qd"]
    end

    # sum p and q for each generator
    for (gen_num_str, gen_data) in case["gen"]
        pgen += gen_data["pg"]
        qgen += gen_data["qg"]
    end

    pratio = pload / pgen
    qratio = qload / qgen

    return pratio, qratio
end
