using JuMP, Cbc, CPLEX              # Optimization and modelling, Gurobi ?
using Plots, LaTeXStrings       # Plotting

# ========================= DATA =========================
# Vectorized operations: https://jump.dev/JuMP.jl/0.17/refexpr.html#vectorized-operations
P_C  = [0 500; 0 500; 0 500; 0 500; 0 500; 1 600; 1 700; 1 800; 1 900; 0 1000;]
P_C  = [1 200; 1 250; 1 300; 1 400; 1 500; 1 600; 1 700; 1 800; 1 900; 1 1000;]
P_C  = [50 200; 25 250; 75 300; 100 400; 125 500; 150 600; 175 700; 200 800; 225 900; 100 1000;]
P_D = [3268.78 3158.69 3036.5 2946.15 2891.74 2909.41 3014.69 3104.31 3243.79 3547.45 3808.79 4134.67 4157.68 4048.36 4184.9 4052.32 4229.83 4510.66 4403.63 4158.34 3916.65 3669.91 3421.24 3164.72 ]*1
P_D = [P_D P_D P_D P_D]
#P_D = LinRange(0, sum(P_C[:,2]), 100)          # Power demand
T = length(P_D)                                 # Number of time steps
N = length(P_C[:,1])                            # Number of generators
#F = rand(100:500,N)                            # Random prod. prices
F = LinRange(100, 500, 11)                      # Power demand
S_up = F[end:-1:1]*100
S_down = F*0.5
T_up = rand(2:4,N)
T_down = rand(1:4,N)
atol = 10e-6                                    # not in use

# ========================= FUNCTIONS =========================
# Recursive functions for minimum operating and shut down time
function consecutive(T_up,n,t,sum=0)
    if T_up > 0
        sum += x[n,t + T_up]
        consecutive(T_up - 1,n,t,sum)
    else
        return sum
    end
end
function consecutive_down(T,n,t,sum=0)
    if T > 0
        sum += x_neg[n,t + T]
        consecutive(T - 1,n,t,sum)
    else
        return sum
    end
end

# ========================= MODEL =========================

# Indicator constraints ?
# Callbacks ? https://jump.dev/JuMP.jl/dev/examples/callbacks/
# Example: https://jump.dev/JuMP.jl/dev/examples/prod/

m = Model(CPLEX.Optimizer)                                  # Model
@variable(m, x[1:N,1:T], Bin,start=0)                       # Unit activation
@variable(m, x_neg[1:N,1:T], Bin,start=0)                   # Negated unit activation
@variable(m, x_up[1:N,1:T], Bin)                            # Unit activation
@variable(m, x_down[1:N,1:T], Bin)                          # Unit activation
@variable(m, P_G[i=1:N,1:T])                                # Power generation

# Time dependent constraints
for t in 1:T
    # Load balance
    @constraint(m, sum(P_G[:,t]) == P_D[t])
end

# Time and unit dependent constraints
for n in 1:N
    for t in 1:T
        # Unit generation limit
        @constraint(m, P_C[n,1]*x[n,t] <= P_G[n,t])
        @constraint(m, P_G[n,t] <= P_C[n,2]*x[n,t])

        # start up and shut down
        if t > 1
            @constraint(m, x_up[n,t] >= -x[n,t-1] + x[n,t])
            @constraint(m, x_down[n,t] >= x[n,t-1] - x[n,t])
        else
            @constraint(m, x_up[n,t] >= 0 + x[n,t])
        end

        # Minimum operation time, Indicator constraint for Bins
        if t > T - T_up[n]
            @constraint(m, x_up[n,t] => {consecutive(T - t,n,t) == T - t})
        else
            @constraint(m, x_up[n,t] => {consecutive(T_up[n],n,t) == T_up[n]})
        end

        # Minimum cool down time, Indicator constraint for Bins
        if t > T - T_down[n]
            @constraint(m, x_down[n,t] => {consecutive_down(T - t,n,t) == (T - t)})
        else
            @constraint(m, x_down[n,t] => {consecutive_down(T_down[n],n,t) == T_down[n]})
        end

        # Creating an inverse matrix of the unit activation matrix
        @constraint(m, x[n,t] => {x_neg[n,t] == 0})              # x_neg = 0 <=>
        @constraint(m, !x[n,t] => {x_neg[n,t] == 1})              # x_neg = 0 <=>
    end
end

@objective(m,Min,
    sum(P_G[:,1:T].*F[1:N])
    + sum(x_up.*S_up[1:N])                                  # Start-up cost
    + sum(x_down.*S_down[1:N])                              # Shut-down cost
)

optimize!(m)                                                # Solve

# ========================= PLOT =========================
linDemand = false
if linDemand
    clrs = [round(Int,i) == 1 ? "green" : "red" for i in value.(x)]        # https://stackoverflow.com/questions/39790031/does-julia-have-a-ternary-conditional-operator
    p1 = plot(                                                      # Unit activation
        P_D[:],value.(P_G[:,1:T])',xtick=0:500:sum(P_C[:,2]),
        ylab = L"P_{unit} [MW]",ylim=(minimum(P_C),maximum(P_C)))
    p2 = scatter(                                                   # Unit activation
        repeat(P_D, 1,N)',
        repeat(1:N, 1,N),
        color=clrs,
        ytick=(1:N, ["$(i), $(F[i]) \$, [$(P_C[i,1])-$(P_C[i,2])] MW" for i in 1:N]),
        legend=false,
        xtick=0:500:sum(P_C[:,2]),
        yflip=true,
        ylab = "unit")
    p3 = plot(P_D[:],
        value.(P_G[:,1:T])'*F[1:N],
        ylab = "\$",
        xtick=0:500:sum(P_C[:,2]),
        xlab = L"P_{load} [MW]")
        plt = plot(p1, p2, p3, layout = (3, 1), legend = false,size=(900,600))
else
    clrs = [round(Int,i) == 1 ? "green" : "red" for i in value.(x)]                             # https://stackoverflow.com/questions/39790031/does-julia-have-a-ternary-conditional-operator
    clrs1 = [round(Int,i) > 0 ? "cyan" : "white" for i in value.(x_up) + value.(x_down)]
    size = [round(Int,i) > 0 ? 6 : 1 for i in value.(x_up) + value.(x_down)]
    p1 = plot(                                                      # Unit activation
        1:T,value.(P_G[:,1:T])',
        #xtick=0:10:T,
        xtick=:none,
        ylab = L"P_{unit} [MW]",ylim=(minimum(P_C),maximum(P_C)))
    p2 = scatter(
        repeat(1:T, 1,N)',
        repeat(1:N, 1,N),
        color=clrs1,
        markerstrokealpha = 0.2,
        markerstrokewidth = 0.2,
        markersize = size,
        ytick=(1:N, ["$(i), $(F[i]) €, [$(P_C[i,1])-$(P_C[i,2])] MW" for i in 1:N]),
        legend=false,
        #xtick=0:10:T,
        xtick=:none,
        yflip=true)
    scatter!(                                                   # Unit activation
        repeat(1:T, 1,N)',
        repeat(1:N, 1,N),
        color=clrs,
        ytick=(1:N, ["$(i), $(F[i]) €, [$(P_C[i,1])-$(P_C[i,2])] MW" for i in 1:N]),
        legend=false,
        #xtick=0:10:T,
        xtick=:none,
        yflip=true,
        ylab = "unit")
    p3 = plot(1:T,
        value.(P_G[:,1:T])'*F[1:N]  + (value.(x_up)[:,1:T]'*S_up[1:N]) + (value.(x_down)[:,1:T]'*S_down[1:N]),
        ylab = "€",
        #title="Total: $(objective_value(m))",
        xtick=0:10:T,
        xlab = L"t")
        plot!(twinx(),1:T,P_D',ytick=:none,color=:black,linestyle=:dot)
    plt = plot(p1, p2, p3, layout = (3, 1), legend = false,size=(900,600))
end
savefig("MIP.png")

@show plt

#@show objective_value(m)
