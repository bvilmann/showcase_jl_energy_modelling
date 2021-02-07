using JuMP, Cbc, Ipopt, Juniper, CPLEX
using Plots, LaTeXStrings

function HR(P_G,P_ratio,P_max,n_opt,a,b,C1,C2)
        return 1/(n_opt*(1+(a*(P_ratio-(P_G/P_max)))+(b*(P_ratio-((P_G/P_max)^2)*C1*C2))))
end

# Vectorized operations: https://jump.dev/JuMP.jl/0.17/refexpr.html#vectorized-operations
P_C  = [200 50;                                         # Power capacity
        200 25;
        200 100;
        500 120;
        500 10;
        500 20;
        800 200;
        800 200;
        800 100;
        1000 200;]

a = 0.051
b = (-0.611)
P_ratio = 0.85
n_opt = 0.35
C1 = 1.012
C2 = 0.96

P_D = LinRange(sum(P_C[:,2]), sum(P_C[:,1]), 100)       # Power demand
T = length(P_D)                                         # Number of time steps
P_max = repeat(P_C[:,1],1,T)
N = length(P_C[:,1])                                    # Number of generators
m = Model(
        optimizer_with_attributes(
                Juniper.Optimizer,
                "nl_solver"=>optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
                "mip_solver"=>optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
                "registered_functions" => [
                        Juniper.register(:HR, 8, HR, autodiff = true)
                        ])
                )


@variable(m, P_C[i,2] <= P_G[i=1:N,1:T] <= P_C[i,1])    # Unit generation limit

for i in 1:T                                            # Load balance
    @constraint(m, sum(P_G[:,i]) == P_D[i])
end

register(m,:HR,8, HR; autodiff=true)

@NLobjective(
        m,
        Min,
        #sum(P_G[1:N,1:T].*HR(P_G[1:N,1:T],P_ratio,P_max[1:N],n_opt,a,b,C1,C2))
        sum(P_G[n,t]*HR(P_G[n,t],P_ratio,P_max[n],n_opt,a,b,C1,C2) for n in 1:N for t in 1:T)
        )

optimize!(m)                                            # Optimize case

F = zeros(N,T)

for n in 1:N
        for t in 1:T
                F[n,t] = value.(P_G)[n,t]*HR(value.(P_G)[n,t],P_ratio,P_max[n],n_opt,a,b,C1,C2)
        end
end

# Plotting hints for datetime https://gist.github.com/dpsanders/ef8e89bf68f304552aa3s
# Plotting tutorial Purdue University: https://www.math.purdue.edu/~allen450/Plotting-Tutorial.html
pyplot()
gr()
plt = plot(P_D[:],value.(P_G[:,1:T])', xlab = L"P_{load} [MW]", ylab = L"P_{unit} [MW]",label=permutedims(["gen$(i)" for i in 1:10]),legendfontsize=7,legendtitlefontsize=10,legendtitle="€",legend=:topleft,dpi=300)
plot!(twinx(),P_D[:],F', ylab = L"cost [€/MWh]",linestyle=:dot,color=:grey,alpha=0.75,label="",xticks=:none, right_margin = Plots.px)
savefig("NLP.png")

#@show plt

# p = plot(rand(10))
# plot!(twinx(p),100rand(10))
# savefig("stack1.png")
#
# plot(rand(10),label="left",legend=:topleft)
# plot!(twinx(),100rand(10),color=:red,xticks=:none,label="right")
# savefig("stack2.png")
