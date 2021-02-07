using JuMP, Cbc
using Plots, LaTeXStrings

# Vectorized operations: https://jump.dev/JuMP.jl/0.17/refexpr.html#vectorized-operations
P_C = hcat([25*i for i in 1:10],[200+50*(i-1) for i in 1:10])
P_D = LinRange(sum(P_C[:,1]), sum(P_C[:,2]), 100)       # Power demand
F = rand(100:10:500,10)                                  # Random prod. prices
T = length(P_D)                                         # Number of time steps
N = length(P_C[:,1])                                    # Number of generators

#
m = Model(Cbc.Optimizer)                                # Model
@variable(m, P_C[i,1] <= P_G[i=1:N,1:T] <= P_C[i,2])    # Unit generation limit
@objective(m,Min,sum(P_G[:,1:T].*F[1:N]))               # Objective function
for i in 1:T                                            # Load balance
    @constraint(m, sum(P_G[:,i]) == P_D[i])
end
optimize!(m)                                            # Optimize case

plt = plot(P_D[:],value.(P_G[:,1:T])', xlab = L"P_{load} [MW]", ylab = L"P_{unit} [MW]", label=permutedims(F),legendtitle="€",legendfontsize=7,legendtitlefontsize=10,legend=:topleft,dpi=300)
#savefig("LP.png")
@show plt
