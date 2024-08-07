module BatteryModel
using JuMP, Infiltrator
import HiGHS

export BatteryParams, optimise_battery_charge

"""
Battery Params
- max_charge_rate - maximum charging rate of the battery - MW
- max_discharging_rate - maximum discharging rate of the battery - MW 
- max_storage_volume - maximum storage volume of the battery - MWh
- charging_efficiency - percentage of energy from the grid that charges the battery - % 
- discharging_efficiency - percentage of energy from the grid that discharges the battery - %
- lifetime_years - maximum number of years of use before the battery become unusable - yrs
- litetime_charges - maximum number of charges cycles that the battery can use - cycles 
- degradiation_rate - the rate at which the battery degrades each charge cycle - % 
- capex - the total capital cost of the battery storage unit - gbp 
- opex - the yearly cost of running the battery storay unit - gbp
"""
struct BatteryParams
    max_charge_rate::Float64
    max_discharge_rate::Float64
    max_storage_volume::Float64 
    charging_efficiency::Float64
    discharging_efficiency::Float64
    lifetime_years::Float64
    lifetime_charges::Float64
    degradation_rate::Float64
    capex::Float64
    opex::Float64
end
"""
optimise_battery_charge(prices, params, del_t=1800)

- computes the optimise battery power going in out of two markets
- Power is defined as the power going INTO the battery
- +ve means charging the battery
- -ve means discharging the battery 
- Using the apple definition of the number of cycles - 
Inputs:
prices: N x 2 matrix representing the two market prices in gbp/MW per half hour
params: parameters of the battery charge
del_t: The time step between each sample - by default 30mins = 1800s
Outputs: 
energies_in: N x 2 matrix representing the amount of power going into the battery from market 1 (col 1) and from market 2 (col 2) per unit time
energies_out: N x 2 matrix representing the amount of power going out of the battery to market 1 (col 1) and to market 2 (col 2)
energy: N x 1 vector representing the battery energy 
cycles: N x 1 vector representing the battery cycles
maximum_capacities: N x 1 vector representing the maximum capacity of the battery
powers: N x 1 vector representing the battery power 
""" 
function optimise_battery_charge(prices, params::BatteryParams, del_t=1800)
    @infiltrate
    N = size(prices)[1]
    overflow = 0.0
    max_samples = Int(round(params.lifetime_years*31536000/del_t))
    if N > max_samples
        overflow = N - max_samples
        N = max_samples
    end
    
    model = Model(HiGHS.Optimizer)
    print("Nearly there")
    @variable(model, energy_in1[1:N], lower_bound=0.0, upper_bound = params.max_storage_volume ) # For market 1
    @variable(model, energy_out1[1:N], lower_bound = 0.0, upper_bound = params.max_storage_volume)
    @variable(model, energy_in2[1:N], lower_bound=0.0, upper_bound = params.max_storage_volume) # For market 2
    @variable(model, energy_out2[1:N], lower_bound = 0.0, upper_bound = params.max_storage_volume)
    @variable(model, powers[1:N], lower_bound=-params.max_discharge_rate, upper_bound=params.max_charge_rate)
    @variable(model, energies[1:N], lower_bound=0.0, upper_bound = params.max_storage_volume)
    @variable(model, cycles[1:N], lower_bound=0.0, upper_bound=params.lifetime_charges)
    @variable(model, maximum_capacities[1:N], lower_bound=0.0, upper_bound=params.max_storage_volume)
    @variable(model, t[1:N], lower_bound=-params.max_storage_volume, upper_bound=params.max_storage_volume) # dummy variable
    
    # Initialisation
    fix(energies[1], 0.0; force=true) # Assume that the battery is not charged at all 
    fix(cycles[1], 0.0; force=true)
    for i in 1:N
        fix(maximum_capacities[i], params.max_storage_volume; force=true) # For there is no change in the max capacities 
    end 
    # Inequality constraints 
    @constraint(model, energy_out_con, energy_out1 + energy_out2 <= (energies)) 
    @constraint(model, energy_in_con, energy_in1 + energy_in1 <= maximum_capacities - energies )
    @constraint(model, abs_pos_con, energy_in1 + energy_in2 - energy_out1 - energy_out2 <= t)
    @constraint(model, abs_neg_con, -(energy_in1 + energy_in2 - energy_out1 - energy_out2) <= t)

    # Equality constraints 
    num_of_hrs = del_t / 3600
    @constraint(model, power_con, powers == (energy_in1 + energy_in2 - energy_out1 - energy_out2)./num_of_hrs)
    @constraint(model, energy_con[i=1:N-1], energies[i+1] == energies[i]+(energy_in1[i] + energy_in2[i] - energy_out1[i] - energy_out2[i])*params.charging_efficiency) # For now just assume charging and discharging gives the same 
    @constraint(model, cycles_con[i=1:N-1], (cycles[i+1] - cycles[i])*params.max_storage_volume == t[i]) 

    # Reduce the cost as much as possible
    @objective(model, Min, transpose(prices[:,1])*(energy_in1 - energy_out1) + transpose(prices[:,2])*(energy_in2 - energy_out2))

    optimize!(model)
    @assert is_solved_and_feasible(model)
    solution_summary(model)

    
    energies_arr = value.(energies)
    energies_in1_arr = value.(energy_in1)
    energies_out1_arr = value.(energy_out1)
    energies_in2_arr = value.(energy_in2)
    energies_out2_arr = value.(energy_out2)
    cycles_arr = value.(cycles)
    max_cap_arr = value.(maximum_capacities)
    powers_arr = value.(powers)
    for i in 1:(N-1)
        lhs_val = energies_arr[i+1]
        rhs_val = energies_arr[i] + (energies_in1_arr[i] + energies_in2_arr[i] - energies_out1_arr[i] - energies_out2_arr[i])*params.charging_efficiency
        @assert  isapprox(lhs_val, rhs_val; atol=1e-5) 
    end

    if overflow > 0
        # Add overflow zeros to the end
        num_of_zeros = overflow 
        last_val_energy = energies_arr[-1]
        last_val_energy_in1 = 0.0
        last_val_energy_in2 = 0.0
        last_val_energy_out1 = 0.0
        last_val_energy_out2 = 0.0
        last_val_cycles = cycles_arr[-1]
        last_val_max_cap = max_cap_arr[-1]
        last_val_powers = 0.0
        while num_of_zeros > 0 
            push!(energies_arr, last_val_energy)
            push!(energies_in1_arr, last_val_energy_in1)
            push!(energies_in2_arr, last_val_energy_in2)
            push!(energies_out1_arr, last_val_energy_out1)
            push!(energies_out2_arr, last_val_energy_out2)
            push!(cycles_arr, last_val_cycles)
            push!(max_cap_arr, last_val_max_cap)
            push!(powers_arr, last_val_powers)
            num_of_zeros -= 1
        end
    end

    # Concaternate the energies in and out
    energies_in_mat = hcat(energies_in1_arr, energies_in2_arr)
    energies_out_mat = hcat(energies_out1_arr, energies_out2_arr)

    return energies_in_mat, energies_out_mat, energies_arr, cycles_arr, max_cap_arr, powers_arr
end

end