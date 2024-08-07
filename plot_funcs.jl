module PlotFuncs

using CSV, DataFrames, Infiltrator, YAML, Plots, Dates
using ..BatteryModel
"""
Calculate the total yearly profits of the battery

- prices - N x 2 matrix representing the prices from market 1 (col 1) and market 2 (col 2) in gbp / MWh
- energies_in - N x 2 matrix representing the energy charging the battery from market 1 (col 1) and market 2 (col 2)
- energies_out - N x 2 matrix representing the energy discharging from the battery to market 1 (col 1) and market 2 (col 2)
- battery_params - primarily need the capex and opex 
- years - operational years of the battery
"""
function calculate_yearly_profits(prices, energies_in, energies_out, battery_params::BatteryParams, years)
    net_revenue = - (transpose(prices[:,1])*(energies_in[:,1] - energies_out[:,1]) + transpose(prices[:,2])*(energies_in[:,2] - energies_out[:,2]))
    return (net_revenue - battery_params.opex*years - battery_params.capex) / years, net_revenue
end

"""
plot_battery_performance(prices, charges, del_t=1800)

Inputs: 
- prices - N x 2 matrix representing the prices from market 1 (col 1) and market 2 (col 2) in gbp / MWh
- energies_in - N x 2 matrix representing the energy charging the battery from market 1 (col 1) and market 2 (col 2)
- energies_out - N x 2 matrix representing the energy discharging from the battery to market 1 (col 1) and market 2 (col 2)
- energies - N x 1 vector representing the battery energy
- powers - N x 1 vector representing the battery power
- cycles - N x 1 vector representing the battery cycles
- maximum_capacities - N x 1 vector representing the max battery capacity
- N is the number of timesteps

- This plots 6 graphs 
- Plot of the prices of each of the markets
- Plot of the energies in of each of the markets
- Plot of the energies out of each of the markets
- Plot of the energy of the battery
- Plot of the cycles of the battery 
- Plot of the maximum capacity of the battery
- Plot of the total costs of each of the markets 
"""
function plot_battery_performance(prices, energies_in, energies_out, energies, powers, cycles, maximum_capacities, del_t=1800, save_folder="plots/")
    N = size(prices)[1] # Will have to change later
    revenues1 = - prices[:,1].*(energies_in[:,1] - energies_out[:,1])
    revenues2 = - prices[:,2].*(energies_in[:,2] - energies_out[:,2])
    revenues = revenues1 + revenues2
    time = del_t .* (1:N) ./ 86400 # in days

    p_prices = plot(time, prices[:,1], xlabel="Time (days)", ylabel="Prices (£)", label="Market 1 Price")
    p_prices = plot!(time, prices[:,2], label="Market 2 Price")
    savefig(p_prices, save_folder*"prices_fig.png")

    p_energies_in = plot(time, energies_in[:,1], xlabel="Time (days)", ylabel="Energy into Battery (MWh)", label="Market 1 intake")
    p_energies_in = plot!(time, energies_in[:,2], label="Market 2 intake")
    p_energies_in = plot!(time, energies_in[:,1]+ energies_in[:,2], label="Total intake")
    savefig(p_energies_in, save_folder*"energies_in_fig.png")

    p_energies_out = plot(time, energies_out[:,1], xlabel="Time (days)", ylabel="Energy out (MWh)", label="Market 1 output")
    p_energies_out = plot!(time, energies_out[:,2], label="Market 2 output")
    p_energies_out = plot!(time, energies_out[:,1]+energies_out[:,2], label="Total output" )
    savefig(p_energies_out, save_folder*"energies_out_fig.png")

    p_revenues = plot(time, revenues, xlabel="Time (date)", ylabel="Revenue (GBP)", label="Total revenues")
    p_revenues = plot!(time, revenues1, xlabel="Time (date)", ylabel="Revenue (GBP)", label="Market 1 revenues")
    p_revenues = plot!(time, revenues2, xlabel="Time (date)", ylabel="Revenue (GBP)", label="Market 2 revenues")
    savefig(p_revenues, save_folder*"revenues_fig.png")

    p_energy = plot(time, energies, xlabel="Time (days)", ylabel="Battery Energy (MWh)", legend=false)
    savefig(p_energy, save_folder*"battery_energy_fig.png")

    p_cycles = plot(time, cycles, xlabel="Time (days)", ylabel="Cycles (MWh)", legend=false)
    savefig(p_cycles, save_folder*"battery_cycles_fig.png")

    p_max_cap = plot(time, maximum_capacities, xlabel="Time (days)", ylabel="Max Capacity (MWh)", legend=false)
    savefig(p_max_cap, save_folder*"battery_max_cap_fig.png")

    p_max_cap = plot(time, powers, xlabel="Time (days)", ylabel="Power in (MW)", legend=false)
    savefig(p_max_cap, save_folder*"power_fig.png")

end
"""
Inputs: 
- prices - N x 2 matrix representing the prices from market 1 (col 1) and market 2 (col 2) in gbp / MWh
- energies_in - N x 2 matrix representing the energy charging the battery from market 1 (col 1) and market 2 (col 2)
- energies_out - N x 2 matrix representing the energy discharging from the battery to market 1 (col 1) and market 2 (col 2)
- energies - N x 1 vector representing the battery energy
- powers - N x 1 vector representing the battery power
- cycles - N x 1 vector representing the battery cycles
- maximum_capacities - N x 1 vector representing the max battery capacity
- start_time - start timestep of the input data
- N is the number of timesteps
"""
function write_battery_performance(prices, energies_in, energies_out, energies, cycles, maximum_capacities, start_time, battery_params::BatteryParams, del_t=1800)
    # Write the total revenue to a text file
    N = size(prices)[1]
    years = N * del_t/ 31536000
    total_profits, net_revenue = calculate_yearly_profits(prices, energies_in, energies_out, battery_params, years)
    file = open("data/output_data/total_profits.txt", "w")
    write(file, "The total revenue (gbp) is $net_revenue\n")
    write(file, "In $years years\n")
    write(file, "The total annual profits (gbp/year) are $total_profits\n")
    close(file)
    # Write the data to a CSV file
    del_timestep = Dates.Second(del_t)
    time_steps = [start_time + i*del_timestep for i in 0:(N-1)]
    output_df = DataFrame(Time=time_steps, Energy_in1=energies_in[:,1], Energy_in2=energies_in[:,2], Energy_out1=energies_out[:,1], Energies_out2=energies_out[:,2], total_energies=energies, battery_cycles=cycles, maximum_capacities=maximum_capacities)
    CSV.write("data/output_data/battery_output_data.cvs", output_df)
end

end