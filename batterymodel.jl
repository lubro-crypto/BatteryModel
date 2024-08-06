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
prices: N x 1 matrix representing the two market prices in gbp/MW per half hour
params: parameters of the battery charge
del_t: The time step between each sample - by default 30mins = 1800s
Outputs: 
energies_in: N x 1 matrix representing the amount of power going into the battery from market 1 (col 1) and from market 2 (col 2)
total_profit: float representing the total costs 
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
    @variable(model, energy_in1[1:N], lower_bound=0.0 ) # For market 1
    @variable(model, energy_out1[1:N], lower_bound = 0.0)
    @variable(model, powers[1:N], lower_bound=-params.max_discharge_rate, upper_bound=params.max_charge_rate)
    @variable(model, energies[1:N], lower_bound=0.0)
    @variable(model, cycles[1:N], lower_bound=0.0, upper_bound=params.lifetime_charges)
    @variable(model, maximum_capacities[1:N], lower_bound=0.0, upper_bound=params.max_storage_volume)
    @variable(model, t[1:N], lower_bound=-params.max_storage_volume, upper_bound=params.max_storage_volume) # dummy variable
    
    # Initialisation
    fix(energies[1], 0.0; force=true) # Assume that the battery is not charged at all 
    fix(cycles[1], 0.0; force=true)
    fix(maximum_capacities[1], params.max_storage_volume; force=true) # For there is no change in the max capacities 
    # Inequality constraints 
    @constraint(model, energy_min_max[i=1:N], energies[i] <= maximum_capacities[i])
    @constraint(model, energy_out_con[i=1:N], energy_out1[i] <= (energies[i])) 
    @constraint(model, energy_in_con[i=1:N], energy_in1[i] <= maximum_capacities[i] - energies[i] )
    @constraint(model, abs_pos_con[i=1:N], energy_in1[i] - energy_out1[i] <= t[i])
    @constraint(model, abs_neg_con[i=1:N], -(energy_in1[i] - energy_out1[i]) <= t[i])

    # Equality constraints 
    num_of_hrs = del_t / 3600
    const_nat_log_deg_rate = log(params.degradation_rate)
    @constraint(model, power_con, powers == (energy_in1 - energy_out1)./num_of_hrs)
    @constraint(model, energy_con[i=1:N-1], energies[i+1] == energies[i]+(energy_in1[i] - energy_out1[i])*params.charging_efficiency) # For now just assume charging and discharging gives the same 
    @constraint(model, cycles_con[i=1:N-1], (cycles[i+1] - cycles[i])*params.max_storage_volume == t[i]) 
    @constraint(model, maximum_cap_con[i=2:N], maximum_capacities[i] == maximum_capacities[i-1] - maximum_capacities[i-1]*(1 + const_nat_log_deg_rate*(cycles[i] - cycles[i-1])))

    # Reduce the cost as much as possible
    @objective(model, Min, sum((energy_in1[i] - energy_out1[i])*prices[i] for i in 1:N))

    optimize!(model)
    @assert is_solved_and_feasible(model)
    solution_summary(model)

    if overflow > 0.0
        # Add overflow zeros to the end

    end
    energies_mat = value.(energies)
    energies_in1_mat = value.(energy_in1)
    energies_out1_mat = value.(energy_out1)
    for i in 1:(N-1)
        lhs_val = energies_mat[i+1]
        rhs_val = energies_mat[i] + (energies_in1_mat[i] - energies_out1_mat[i])*params.charging_efficiency
        @assert  isapprox(lhs_val, rhs_val; atol=1e-5) 
    end

    return value.(energy_in1), value.(energy_out1), value.(energies), value.(cycles), value.(maximum_capacities), value.(powers)
end

end