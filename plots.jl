# ================== Initializing ==================
# ------------------ Packages ------------------
# Plot packages
using Plots
using LaTeXStrings
using StatsPlots        # For groupedbar
using Compose

# For statistical function
using StatsBase

#Shape files (NUTS)
using PlotShapefiles
using DBFTables

# ------------------ Map data ------------------
test = open_shapefile("plots/nuts/1000_NUTS1.shp")
data = load("plots/nuts/DataTable.xlsx","DataTable") |> DataFrame
test_df = DBFTables.Table("plots/nuts/1000_NUTS1.dbf") # Read DBF file

test_df2                = DataFrame(test_df) # Convert to DataFrame
test_df2[!, :shapes]    = test.shapes # Add shapes to DataFrame

de = innerjoin(test_df2, data, on = :NUTS_CODE)[1:16,:]
de = sort(de,[:data])

# ================== HELPER FUNCTIONS ==================
function getColor()
    return clr = [
      RGB(0/255,102/255,0/255)           # Green
      RGB(25/255,0/255,255/255)          # Blue
      RGB(128/255,212/255,255/255)       # Light blue
      RGB(100/255,150/255,255/255)       # Light blue
      RGB(255/255,247/255,0/255)         # Yellow
      RGB(0/255,150/255,0/255)           # Green
      RGB(255/255,0/255,0/255)           # Red
      RGB(133/255,94/255,66/255)         # Brown
      RGB(0.2,0.2,0.2)                   # Black / dark grey
      RGB(255/255,140/255,25/255)        # Carrot
      RGB(25/255,0/255,150/255)          # Blue
      RGB(255/255,0/255,255/255)         # Brown
      ]
end

function initModelDoc(model)

    if nl
        #
    else
        global generation  = value.(model.obj_dict[:generation])
        global flow        = value.(model.obj_dict[:flow])
        global flow_abs    = value.(model.obj_dict[:flow_abs])
        global flow_to     = value.(model.obj_dict[:flow_to])
        global flow_to_abs = value.(model.obj_dict[:flow_to_abs])
        global conducting  = value.(model.obj_dict[:conducting])
        global plant       = value.(model.obj_dict[:plant])
        global demand      = value.(model.obj_dict[:demand])
        global dir         = value.(model.obj_dict[:dir])

        if MIP_unit
            global x = value.(model.obj_dict[:x])
            global x_up = value.(model.obj_dict[:x_up])
        end

    end
    global t = 1
    global energy = names(dfm)[9:end-1]
    global N = size(plant,1)
    global F = size(plant,2)
    global T = size(plant,3)
    global lw = 0.2
    global dpi = 150
    global line_arrow = :arrow
    global clr = getColor()
    global co2 = [230 24 11 12 48 38 12 820 820 490 24 656]

    global M = Array{Float64}(undef,F,T)
    sums = sum(plant,dims=1)
    for i in 1:F
        for j in 1:T
            M[i,j] = sums[1,i,j]
        end
    end
end

# ================== PLOT FUNCTIONS ==================
function plotDE(df,lw=0.02,dpi=100,data=:data,title="",clrbar_title="",clrbar=:best,fill=true,fill_clr=:blues)
    global minx = 10e16
    global miny = 10e16
    global maxx = 0
    global maxy = 0
    for i in 1:16
        polygon = df[:,:shapes][i]
        pointz = [(parse(Float64,split(string(p)[17:end-1],",")[1]),parse(Float64,split(string(p)[17:end-1],",")[2])) for p in polygon.points]
        z = df[:,data][i]

        #fillclr = clrschm(z,minimum(df[:,data]),maximum(df[:,data]))
        # fillclr = cgrad([:white,:blue],[minimum(df[:,data]),maximum(df[:,data])])

        dminx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[1])
        dminy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[2])
        dmaxx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[3])
        dmaxy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[4])

        if i == 1
            if length(polygon.parts) == 1
                if fill
                    global p = plot(
                        Shape(pointz),
                        legend=:none,
                        label = "",
                        colorbar=:top,
                        fill_z = z,
                        aspect_ratio=1,
                        linewidth=lw,
                        grid=:none,
                        framestyle=:none,
                        dpi = dpi,
                        colorbar_title=clrbar_title,
                        c = fill_clr,
                        title=title,
                        colorbar_title_location=:top,
                        bottom_margin=-30px
                    )
                else
                    global p = plot(
                        Shape(pointz),
                        legend=:none,
                        label = "",
                        aspect_ratio=1,
                        linewidth=lw,
                        grid=:none,
                        framestyle=:none,
                        dpi = dpi,
                        color = :white,
                        title=title,
                        bottom_margin=-30px
                    )
                end
            else
                cnt = 1
                finish = length(pointz)
                segments = Tuple{Float64, Float64}[]
                for idx in polygon.parts[2:end]
                    segments = Tuple{Float64, Float64}[]
                    for point in pointz[cnt:idx]
                        push!(segments,(point[1],point[2]))
                    end
                    if cnt == 1
                        if fill
                            global p = plot(
                                Shape(segments),
                                legend=:none,
                                label = "",
                                colorbar=:top,
                                fill_z = z,
                                linewidth=lw,
                                grid=:none,
                                aspect_ratio=1,
                                framestyle=:none,
                                dpi = dpi,
                                colorbar_title=clrbar_title,
                                c = fill_clr,
                                title=title,
                                colorbar_title_location=:top,
                                bottom_margin=-30px
                            )
                        else
                            global p = plot(
                                Shape(segments),
                                legend=:none,
                                label = "",
                                linewidth=lw,
                                grid=:none,
                                aspect_ratio=1,
                                color = :white,
                                framestyle=:none,
                                dpi = dpi,
                                title=title,
                                bottom_margin=-30px
                            )
                        end
                    else
                        if fill
                            plot!(Shape(segments),fill_z = z,linewidth=lw,colorbar=:best,c = :blues,label="")
                        else
                            plot!(Shape(segments),linewidth=lw,color=:white,label="")
                        end
                    end

                    cnt = idx + 1
                end
                segments = Tuple{Float64, Float64}[]
                for point in pointz[cnt:finish]
                    push!(segments,(point[1],point[2]))
                end
                if fill
                    plot!(Shape(segments),fill_z = z,linewidth=lw,colorbar=:best,c = :blues,label="")
                else
                    plot!(Shape(segments),linewidth=lw,color=:white,label="")
                end
            end
        else
            if length(polygon.parts) == 1
                if fill
                    plot!(Shape(pointz),fill_z = z,colorbar=:best,linewidth=lw,c = :blues,label="")
                else
                    plot!(Shape(pointz),linewidth=lw,color=:white,label="")
                end
            else
                cnt = 1
                finish = length(pointz)
                for idx in polygon.parts[2:end]

                    ddminx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[1])
                    ddminy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[2])
                    ddmaxx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[3])
                    ddmaxy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[4])

                    if ddminx > dminx && ddminy > dminy && ddmaxx < dmaxx && ddmaxy < dmaxy
                        fillclr = RGBA(0,0,0,1)
                    end
                    segments = Tuple{Float64, Float64}[]
                    for point in pointz[cnt:idx]
                        push!(segments,(point[1],point[2]))
                    end
                    if fill
                        plot!(Shape(segments),fill_z = z,linewidth=lw,colorbar=:best,c = :blues,label="")
                    else
                        plot!(Shape(segments),linewidth=lw,color=:white,label="")
                    end
                    cnt = idx + 1
                end
                segments = Tuple{Float64, Float64}[]
                for point in pointz[cnt:finish]
                    push!(segments,(point[1],point[2]))
                end
                if fill
                    plot!(Shape(segments),fill_z = z,linewidth=lw,colorbar=:best,c = :blues,label="")
                else
                    plot!(Shape(segments),linewidth=lw,color=:white,label="")
                end
            end
        end

        # Controlling min and max dim of plot
        if minx > dminx
            global minx = dminx
        end
        if miny > dminy
            global miny = dminy
        end
        if maxx < dmaxx
            global maxx = dmaxx
        end
        if maxy < dmaxy
            global maxy = dmaxy
        end
    end

    xx = [
    (maxx-minx)*0.3875+minx           #1
    (maxx-minx)*0.6+minx            #2
    (maxx-minx)*0.8125+minx         #3
    (maxx-minx)*0.725+minx           #4
    (maxx-minx)*0.325+minx          #5
    (maxx-minx)*0.45+minx           #6
    (maxx-minx)*0.325+minx           #7
    (maxx-minx)*0.65+minx           #8
    (maxx-minx)*0.425+minx           #9
    (maxx-minx)*0.175+minx           #10
    (maxx-minx)*0.175+minx          #11
    (maxx-minx)*0.1125+minx            #12
    (maxx-minx)*0.775+minx            #13
    (maxx-minx)*0.625+minx            #14
    (maxx-minx)*0.3875+minx            #15
    (maxx-minx)*0.575+minx            #16
    ]
    yy = [
    (maxy-miny)*0.2+miny            #1
    (maxy-miny)*0.25+miny           #2
    (maxy-miny)*0.685+miny          #3
    (maxy-miny)*0.685+miny          #4
    (maxy-miny)*0.75+miny           #5
    (maxy-miny)*0.806125+miny       #6
    (maxy-miny)*0.425+miny           #7
    (maxy-miny)*0.825+miny          #8
    (maxy-miny)*0.65+miny           #9
    (maxy-miny)*0.525+miny         #10
    (maxy-miny)*0.35+miny           #11
    (maxy-miny)*0.275+miny         #12
    (maxy-miny)*0.5+miny            #13
    (maxy-miny)*0.625+miny            #14
    (maxy-miny)*0.9+miny            #15
    (maxy-miny)*0.475+miny            #16
    ]
    return (p,xx,yy)
end

function plotGermany(t)
    p,xx,yy = plotDE(de,lw,300,:data,"","",:none,false)

    for line in Lines
        val = (flow_abs[line,t]) / line.capacity

        println(line.from_state,"\n",line.to_state,"\n",val,"\n\n")

        if abs(val) > 0.9
            line_clr = RGB(1,0,0)
        elseif abs(val) > 0.5
            line_clr = RGB(1,1,0)
        elseif abs(val) > 0
            line_clr = RGB(0,1,0)
        else
            line_clr = RGB(0.5,0.5,0.5)
        end
        plot!([xx[line.from],xx[line.to]],[yy[line.from],yy[line.to]],
        arrow = :none,
        color = line_clr,
        alpha = 0.5,
        linewidth = 1
        )
    end
    for state in States
        scatter!(
        [xx[state.node]], [yy[state.node]],
        markersize=12,
        series_annotation=[Plots.text("$(state.node)",10)],
        color=:grey,
        alpha=0.5,
        )
    end
    return p
end

function plotCongestion(lines = true,legend=:outerleft,name="names",summer=false)
    norm_flow = flow_abs
    lab = ["$(replace(line.from_state,"-"=>" ")) - $(replace(line.to_state,"-"=>" "))" for line in Lines[end:-1:1]]
    lab = ["$(line.from) - $(line.to)" for line in Lines[end:-1:1]]
    for line in Lines
        for t in 1:T
            norm_flow[line,t] = (flow[line,t]) / line.capacity
        end
    end
    function rect(w, h, x, y)
        return Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    end

    if name == "names"
        lab = ["$(replace(line.from_state,"-"=>" ")) - $(replace(line.to_state,"-"=>" "))" for line in Lines[end:-1:1]]
    elseif name == "numbers"
        lab = ["$(line.from) - $(line.to)" for line in Lines[end:-1:1]]
    end
    pyplot()
    p1 = heatmap(
        norm_flow.data,
        size=(1200,500),
        colorbar=:top,
        ytick=(1:29,lab),
        xtick=(0:10:168),
        xlim=(1,168),
        ylabel="State number",
        c = cgrad([:blue,:white,:red],[-1,0,1]),
        )
    if lines
        if summer
            vline!([20,29,126,140],color=:black,label="")
        else
            vline!([40,47,129,137],color=:black,label="")
        end
    end

    if lines
        if summer
            # w,h,x,y
            p2 = plot(rect(9,4e4,20,0),fill=:black,opacity=0.1,label="")
            plot!(rect(14,4e4,126,0),fill=:black,opacity=0.1,label="")
            vline!([20,29,126,140],color=:black,label="")
        else
            p2 = plot(rect(7,4e4,40,0),fill=:black,opacity=0.1,label="")
            plot!(rect(8,4e4,129,0),fill=:black,opacity=0.1,label="")
            vline!([40,47,129,137],color=:black,label="")

        end
        plot!(M[3:5,:]',
        linecolor=:black,
        linewidth=3,
        label=""
        )
    else
        p2 = plot(M[3:5,:]',
        linecolor=:black,
        linewidth=3,
        label=""
        )


    end



    plot!(M[3:5,:]',
        legend=legend,
        #legend=:none,
        linecolor=clr[3:5]',
        label=["Wind (onshore)" "Wind (offshore)     " "Photovoltaic"],
        #title="$(T_range[1]) - $(T_range[2])",
        linewidth=2,
        xlims = (1,T),
        ylims = (0, 4e4),
        xtick=(0:10:168),
        xlabel="time [h]",
        ylabel="Power [MW]"
        )


    p = plot(p1,p2,
        size=(1200,800),
        dpi = 300,
        right_margin=50px,
        top_margin=80px,
        layout = @layout[a{0.8h,1w}; b{0.2h,1w};])
    return p
end


function Pie(y,clr)
  s = sum(y)
  θ = 0
  p = plot(grid=false,ticks=false,framestyle=:none,legend=:none)
  for i in 1:length(y)
      θ_new = θ + 2π * y[i] / s
      plot!([(0,0); Plots.partialcircle(θ,θ_new,50)], seriestype = :shape, aspectratio = 1,color=clr[i],title="Energy mix")
      θ = θ_new
  end
  return p
end
function plotRealData(T_range)
    clr = getColor()
    t0 = Date(2019,01,01)
    t1 = Date(parse(Int64,split(T_range[1],"-")[1]),parse(Int64,split(T_range[1],"-")[2]),parse(Int64,split(T_range[1],"-")[3]))
    t2 = Date(parse(Int64,split(T_range[2],"-")[1]),parse(Int64,split(T_range[2],"-")[2]),parse(Int64,split(T_range[2],"-")[3]))
    T           = ((t2-t1).value+1)*24
    T_offset    = (t1-t0).value*24

    a = gen[T_offset+1:T_offset+T,:]

    a[:,[3,4]] = a[:,[4,3]]

    p = areaplot(a.*4,
        dpi = 200,
        #legend=:outertopright,
        legend=:none,
        fill=clr',
        linecolor=clr',
        #label=permutedims([energy]),
        label = permutedims(["Biomass","Hydro","Wind (onshore)","Wind (offshore)","Photovoltaic","Geothermal","Nuclear","Lignite","Hard coal","Natural Gas","Pump storage","Other conventional"]),
        #title="$(T_range[1]) - $(T_range[2])",
        xlims = (1,T),
        ylims = (0, 8e4),
        xlabel="time [h]",
        ylabel="Power [MW]"
        )
    return (p)
end

# --------------- Dashboard plots ---------------
# 1
function GroupedBar(t=1,anim=false)
    if anim
        return groupedbar(
          #plant[:,:,t],
          plant[:,end:-1:1,t],
          bar_position = :stack,
          bar_width=0.7,
          #color = hcat(["grey" for i in 1:N],clr),
          yflip=true,
          xlab = L"P_{generation} [MW]",
          xlim=(0,ceil(maximum(generation)/1000)*1000),
          xtick=0:6e3:ceil(maximum(value.(generation))/1000)*1000,
          ylabel="State",
          title="Generation per state",
          color=clr[end:-1:1]',
          label = permutedims(energy),
          legend=:none,
          ytick=1:N,
          orientation=:horizontal,
          framestyle=:box
          )
    else
        return groupedbar(
          #plant[:,:,t],
          plant[:,end:-1:1,t],
          bar_position = :stack,
          bar_width=0.7,
          #color = hcat(["grey" for i in 1:N],clr),
          yflip=true,
          xlab = L"P_{generation} [MW]",
          xlim=(0,maximum(generation[:,t])),
          color=clr[end:-1:1]',
          label = permutedims(energy),
          legend=:none,
          ytick=1:N,
          orientation=:horizontal,
          framestyle=:box
          )
    end
end

# 2
function PlotMap(t=-1,anim=false)
    if anim
        #gr()
        msize = 0
        tsize = 10
    else
        msize = 6
        tsize = 5
    end

    p2,xx,yy = plotDE(de,lw,dpi,:data,"Showcase of Energy Modeling with Julia\nGermany: $(T_range[1]) - $(T_range[2])","Demand / Capacity")

    for line in Lines
        if t == -1
            val = mean(flow[line,:]) / line.capacity
        else
            val = flow[line,t] / line.capacity
        end

        if abs(val) > 0.9
            line_clr = RGB(1,0,0)
            line_arrow = :arrow
        elseif abs(val) > 0.7
            line_clr = RGB(1,1,0)
            line_arrow = :arrow
        elseif abs(val) > 0
            line_clr = RGB(0,1,0)
            line_arrow = :arrow
        else
            line_clr = RGB(0.5,0.5,0.5)
            line_arrow = :none
        end

        if dir[line,t] == 1
            P1,P2 = [xx[line.from],xx[line.to]],[yy[line.from],yy[line.to]]
        else
            P1,P2 = [xx[line.to],xx[line.from]],[yy[line.to],yy[line.from]]
        end

        plot!(P1,P2,
            arrow = line_arrow,
            color = line_clr,
            alpha = 0.5,
            linewidth = 1
        )
    end
    for state in States
        #if state.node == 3 || state.node == 8
        if state.node == 3
            tclr = :white
        else
            tclr = :black
        end


        scatter!(
        [xx[state.node]], [yy[state.node]],
        markersize=msize,
        series_annotation=[Plots.text("$(state.node)",tsize,tclr)],
        color=:tan,
        alpha=0.5,
        )
    end
    return p2
end

# 3
function PieChart(t=-1)
    if t == -1
        return Pie(mean(sum(plant[:,:,:],dims=1),dims=3),clr)
    else
        return Pie(sum(plant[:,:,t],dims=1),clr)
    end
end

# 5
function Co2Plot(t)
    co2 = [230 24 11 12 48 38 12 820 820 490 24 656]
    M_norm = Array{Float64}(undef,F,T)
    sums = sum(plant,dims=1)
    for i in 1:F
        for j in 1:T
            M_norm[i,j] = sums[1,i,j] / sum(plant[:,:,j])
        end
    end
    p = violin(
        sum(M_norm.*co2',dims=1)',
        xtick=(1:1:1,""),
        ylabel = "gCO2eq/kWh",
        c=:white,
        legend=:none,
        title="CO2 emissions"
        )
    plot!(
        [1.5,0.5],
        [sum(M_norm.*co2',dims=1)'[t],sum(M_norm.*co2',dims=1)'[t]],
        label="",
        xlim=(0.5,1.5),
        arrow=:arrow,
        c = cgrad([:green, :yellow, :red, :brown, :black], [i for i in 1:maximum(sum(M_norm.*co2',dims=1))/5:maximum(sum(M_norm.*co2',dims=1))+1]),
        linewidth=1.5)
    return p
end

# 6
function CostPlot(t)
    c_1 = [5 5 0 0 0 0 5 8.9 8.9 16.3 5 36.8]
    c_2 = [5000 5000 0 0 0 0 5000 5000 4500 2500 5000 4500]
    eff = [1 1 1 1 1 1 1 (1/0.35) (1/0.35) (1/0.5) 1 (1/0.5)]
    cost = plant[:,:,:].*c_1.*eff + x_up[:,:,:].*c_2 + plant[:,:,:].*CO2price.*co2./1000
    p = violin(
        [sum(sum(cost,dims=1),dims=2)[1,1,i] for i in 1:T],
        xtick=(1:1:1,""),
        ylabel = "€",
        c=:white,
        legend=:none,
        title="Cost"
    )

    plot!(
        [1.5,0.5],
        [[sum(sum(cost,dims=1),dims=2)[1,1,i] for i in 1:T][t],[sum(sum(cost,dims=1),dims=2)[1,1,i] for i in 1:T][t]],
        label="",
        xlim=(0.5,1.5),
        arrow=:arrow,
        c = :red,
        linewidth=1.5)

    return p
end


# 7
function AreaPlot()
    lab = ["Biomass","Hydro","Wind (onshore)","Wind (offshore)","Photovoltaic","Geothermal","Nuclear","Lignite","Hard coal","Natural Gas","Pump storage","Other conventional"]
    p6 = areaplot(M',
        dpi = 200,
        legend=:outertopright,
        #legend=:none,
        fill=clr',
        linecolor=clr',
        label = permutedims(["$(i): $(lab[i])" for i in 1:F]),
        xlims = (1,T),
        xtick = 0:12:T,
        ylims = (0, 8e4),
        xlabel="time [h]",
        ylabel="Power [MW]"
        )
end

function Dashboard(t)
    println(t," / ",T)

    p1 = GroupedBar(t,true)    # 1

    p2 = PlotMap(t,true)      # 2

    p3 = PieChart(t)      # 3

    # p4 = heatmap(value.(x)[:,:,t].*replace(pcap .>0,0=>missing),xticks=1:F,yticks=1:N,
    #     c = cgrad([:red,:green],[0,1]),
    #     colorbar=:none,
    #     grid = :none,
    #     yflip=true
    # )

    p4 = heatmap(value.(plant)[:,:,t].*replace(pcap .>0,0=>missing)./P_C[:,:,t],xticks=1:F,yticks=1:N,
        c = cgrad([:red,:green],[0,1]),
        colorbar=:none,
        grid = :none,
        title="gen/cap ratio",
        xlab="Energy type",
        ylab="State",
        yflip=true
    )

    p5 = Co2Plot(t)

    p6 = CostPlot(t)

    p7 = AreaPlot()      # 6
    plot!([t,t],[0,8e4],color=:red,label="",linewidth=1.5)

    return plot(
    p1,p2,p3,p4,p5,p6,p7,size = (1200, 900),dpi=150,
        #plot_title = "Solving the Unit Commitment Problem with Julia",
        #annotation=[0.95,0.05, text("Showcase made @ Technische Universität München",:red,:right)],
        #layout = @layout [grid(2, 1, heights=[0.7 ,0.3], widths=[1]) [grid(1,2, heights=[1],widths=[0.5,0.5]); a{0.7h}];]
        layout = @layout [a{0.2w, 1h} a{0.5w, 1h} [a{1w, 0.3h};a{1w, 0.4h};a{0.5w, 1h} a{0.5w, 1h}]; a{0.25h,1w};]
    )
end

function AnimateDashboard()
    anim = @animate for t in 1:T
        Dashboard(t)
    end
    return anim
end


#
# function plotModel(save=false)
#     clr = getColor()
#
#     M = Array{Float64}(undef,F,T)
#     sums = sum(value.(plant),dims=1)
#     for i in 1:F
#       for j in 1:T
#         M[i,j] = sums[1,i,j]
#       end
#     end
#
#     lab = Array{String}(undef, (1,F))
#     for i in 1:F
#       lab[i] = "$(i): $(energy[i])"
#     end
#
#     p1 = groupedbar(
#       #value.(plant)[:,:,t],
#       value.(plant)[:,end:-1:1,t],
#       bar_position = :stack,
#       bar_width=0.7,
#       #color = hcat(["grey" for i in 1:N],clr),
#       yflip=true,
#       xlab = L"P_{generation} [MW]",
#       #xlim=(0,maximum(value.(generation))),
#       color=clr[end:-1:1]',
#       label = lab,
#       legend=:none,
#       ytick=1:N,
#       orientation=:horizontal,
#       framestyle=:box
#       )
#
#     p2 = plotDE(de,lw,dpi)
#
#     for line in Lines
#         val = value.(flow)[line,t] / line.capacity
#
#         #println(line.from_state,"\n",line.to_state,"\n",val,"\n\n")
#
#         if abs(val) > 0.9
#             line_clr = RGB(1,0,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0.5
#             line_clr = RGB(1,1,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0
#             line_clr = RGB(0,1,0)
#             line_arrow = :arrow
#         else
#             line_clr = RGB(0.5,0.5,0.5)
#             line_arrow = :none
#         end
#
#         if value.(dir)[line,t] == 1
#             P1,P2 = [xx[line.from],xx[line.to]],[y[line.from],y[line.to]]
#         else
#             P1,P2 = [xx[line.to],xx[line.from]],[y[line.to],y[line.from]]
#         end
#
#         plot!(P1,P2,
#             arrow = line_arrow,
#             color = line_clr,
#             alpha = 0.5,
#             linewidth = 1
#         )
#     end
#
#     p3 = Pie(sum(value.(plant)[:,:,t],dims=1),clr)
#
#     p4 = heatmap(value.(x)[:,:,t].*replace(pcap .>0,0=>missing),xticks=1:F,yticks=1:N,
#         c = cgrad([:red,:green],[0,1]),
#         colorbar=:none,
#         grid = :none,
#         yflip=true
#     )
#
#     p5 = heatmap(value.(plant)[:,:,t].*replace(pcap .>0,0=>missing)./P_C[:,:,t],xticks=1:F,yticks=1:N,
#         c = cgrad([:red,:green],[0,1]),
#         colorbar=:none,
#         grid = :none,
#         yflip=true
#     )
#
#     p6 = areaplot(M',
#         dpi = 150,
#         legend=:outertopright,
#         fill=clr',
#         linecolor=clr',
#         label=lab,
#         xlims = (1,T),
#         ylims = (0, 8e4),
#         xlabel="time [h]",
#         ylabel="Power [MWh]"
#     )
#
#     if save
#         savefig("Energy_share_model.png") # save the most recent fig as fn
#     end
# end
#
#
# # ====================== Data ======================


# line_arrow = :arrow
# lw = 0.2
# dpi = 150
# minx = 10e16
# miny = 10e16
# maxx = 0
# maxy = 0
# plotDE(de)
# xx = [
#     (maxx-minx)*0.3875+minx           #1
#     (maxx-minx)*0.6+minx            #2
#     (maxx-minx)*0.8125+minx         #3
#     (maxx-minx)*0.725+minx           #4
#     (maxx-minx)*0.325+minx          #5
#     (maxx-minx)*0.45+minx           #6
#     (maxx-minx)*0.325+minx           #7
#     (maxx-minx)*0.65+minx           #8
#     (maxx-minx)*0.425+minx           #9
#     (maxx-minx)*0.175+minx           #10
#     (maxx-minx)*0.175+minx          #11
#     (maxx-minx)*0.1125+minx            #12
#     (maxx-minx)*0.775+minx            #13
#     (maxx-minx)*0.625+minx            #14
#     (maxx-minx)*0.3875+minx            #15
#     (maxx-minx)*0.575+minx            #16
#     ]
# y = [
#     (maxy-miny)*0.2+miny            #1
#     (maxy-miny)*0.25+miny           #2
#     (maxy-miny)*0.685+miny          #3
#     (maxy-miny)*0.685+miny          #4
#     (maxy-miny)*0.75+miny           #5
#     (maxy-miny)*0.806125+miny       #6
#     (maxy-miny)*0.425+miny           #7
#     (maxy-miny)*0.825+miny          #8
#     (maxy-miny)*0.65+miny           #9
#     (maxy-miny)*0.525+miny         #10
#     (maxy-miny)*0.35+miny           #11
#     (maxy-miny)*0.275+miny         #12
#     (maxy-miny)*0.5+miny            #13
#     (maxy-miny)*0.625+miny            #14
#     (maxy-miny)*0.9+miny            #15
#     (maxy-miny)*0.475+miny            #16
#     ]
#
#
# anim = @animate for t in 1:3
#     println(t,"\t",T)
#
#     p = plotDE(de,lw,dpi)
#
#     for line in Lines
#         val = value.(flow)[line,t] / line.capacity
#
#         println(line.from_state,"\n",line.to_state,"\n",val,"\n\n")
#
#         if abs(val) > 0.9
#             line_clr = RGB(1,0,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0.5
#             line_clr = RGB(1,1,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0
#             line_clr = RGB(0,1,0)
#             line_arrow = :arrow
#         else
#             line_clr = RGB(0.5,0.5,0.5)
#             line_arrow = :none
#         end
#
#         if value.(dir)[line,t] == 1
#             P1,P2 = [xx[line.from],x[line.to]],[y[line.from],y[line.to]]
#         else
#             P1,P2 = [xx[line.to],x[line.from]],[y[line.to],y[line.from]]
#         end
#
#         plot!(P1,P2,
#             arrow = line_arrow,
#             color = line_clr,
#             alpha = 0.5,
#             linewidth = 1
#         )
#     end
# end
# gif(anim,"gif_transport.gif",fps=6)
#
#
# p2 = plotDE(de,lw,dpi)
# for line in Lines
#     val = value.(flow)[line,t] / line.capacity
#
#     #println(line.from_state,"\n",line.to_state,"\n",val,"\n\n")
#
#     if abs(val) > 0.9
#         line_clr = RGB(1,0,0)
#         line_arrow = :arrow
#     elseif abs(val) > 0.5
#         line_clr = RGB(1,1,0)
#         line_arrow = :arrow
#     elseif abs(val) > 0
#         line_clr = RGB(0,1,0)
#         line_arrow = :arrow
#     else
#         line_clr = RGB(0.5,0.5,0.5)
#         line_arrow = :none
#     end
#
#     if value.(dir)[line,t] == 1
#         plt = [xx[line.from],xx[line.to]],[y[line.from],y[line.to]]
#     else
#         plt = [xx[line.to],xx[line.from]],[y[line.to],y[line.from]]
#     end
#
#     print(plt)
#
#     plot!(plt[1],plt[2],
#         arrow = line_arrow,
#         color = line_clr,
#         alpha = 0.5,
#         linewidth = 1
#     )
# end
#
# # ============================== ANIMATION ==============================
#
# p = plot()
#
# # NORMALIZED PRODUCTION
# value.(plant) ./ P_C
#
# anim = @animate for t ∈ 1:T
#     p5 = heatmap(value.(plant)[:,:,t].*replace(pcap .>0,0=>missing)./P_C[:,:,t],xticks=1:F,yticks=1:N,
#     #p2 = heatmap(value.(x)[:,:,t].*replace(pcap .>0,0=>missing),xticks=1:F,yticks=1:N,
#     c = cgrad([:red,:green],[0,1]),
#     colorbarticks=0:0.25:1,
#     grid = :none,
#     yflip=true
#   )
# end
#
# gif(anim, "gif_heatmap_test2.gif", fps = 15)
#
# anim = @animate for t ∈ 1:T
#   p1 = areaplot(M',
#     dpi = 150,
#     legend=:outertopright,
#     fill=clr',
#     label=lab,
#     xlims = (1,T),
#     ylims = (0, 8e4),
#     xlabel="time [h]",
#     ylabel="Power [MWh]"
#     )
#     plot!([t,t],[0,8e4],color=:red,label="")
# end
# gif(anim, "anim_energy_shares.gif", fps = 15)
#
# anim = @animate for t ∈ 1:T
#   p3 = Pie(sum(value.(plant)[:,:,t],dims=1),clr)
# end
# @show anim
# gif(anim, "anim_pie.gif", fps = 15)
#
# # FINAL ANIMATION!
# anim = @animate for t in 1:T
#     println(t," / ",T)
#     p1 = groupedbar(
#       value.(plant)[:,end:-1:1,t],
#       bar_position = :stack,
#       bar_width=0.7,
#       #color = hcat(["grey" for i in 1:N],clr),
#       yflip=true,
#       xlab = L"P_{generation} [MW]",
#       ylab="State",
#       xlim=(0,ceil(maximum(value.(generation))/1000)*1000),
#       color=clr[end:-1:1]',
#       ytick=1:N,
#       title="Production per state",
#       legend=:none,
#       xtick=0:6e3:ceil(maximum(value.(generation))/1000)*1000,
#       orientation=:horizontal,
#       framestyle=:box
#       )
#
#     p2 = plotDE(de,lw,dpi)
#
#     for line in Lines
#         val = value.(flow)[line,t] / line.capacity
#
#         #println(line.from_state,"\n",line.to_state,"\n",val,"\n\n")
#
#         if abs(val) > 0.9
#             line_clr = RGB(1,0,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0.5
#             line_clr = RGB(1,1,0)
#             line_arrow = :arrow
#         elseif abs(val) > 0
#             line_clr = RGB(0,1,0)
#             line_arrow = :arrow
#         else
#             line_clr = RGB(0.5,0.5,0.5)
#             line_arrow = :none
#         end
#
#         if value.(dir)[line,t] == 1
#             plt = [xx[line.from],xx[line.to]],[y[line.from],y[line.to]]
#         else
#             plt = [xx[line.to],xx[line.from]],[y[line.to],y[line.from]]
#         end
#
#         plot!(plt,
#             arrow = line_arrow,
#             color = line_clr,
#             alpha = 0.5,
#             linewidth = 1
#         )
#     end
#
#     p3 = Pie(sum(value.(plant)[:,:,t],dims=1),clr)
#
#     p4 = heatmap(value.(x)[:,:,t].*replace(pcap .>0,0=>missing),xticks=1:F,yticks=1:N,
#         c = cgrad([:red,:green],[0,1]),
#         colorbar=:none,
#         grid = :none,
#         yflip=true
#     )
#
#     p5 = heatmap(value.(plant)[:,:,t].*replace(pcap .>0,0=>missing)./P_C[:,:,t],xticks=1:F,yticks=1:N,
#         c = cgrad([:red,:green],[0,1]),
#         colorbar=:none,
#         grid = :none,
#         title="gen/cap ratio",
#         xlab="Energy type",
#         ylab="State",
#         yflip=true
#     )
#
#     p6 = areaplot(M',
#         dpi = 150,
#         legend=:outertopright,
#         fill=clr',
#         linecolor=clr',
#         label=lab,
#         xlims = (1,T),
#         ylims = (0, 8e4),
#         xlabel="time [h]",
#         ylabel="Power [MWh]"
#     )
#     plot!([t,t],[0,8e4],color=:red,label="",linewidth=1.5)
#     plot(
#     p1,p2,p3,p5,p6,size = (1200, 900),dpi=150,
#     #plot_title = "Solving the Unit Commitment Problem with Julia",
#     #annotation=[0.95,0.05, text("Showcase made @ Technische Universität München",:red,:right)],
#     #layout = @layout [grid(2, 1, heights=[0.7 ,0.3], widths=[1]) [grid(1,2, heights=[1],widths=[0.5,0.5]); a{0.7h}];]
#     layout = @layout [a{0.2w, 1h} a{0.5w, 1h} [a{1w, 0.3h};a{1w, 0.3h}]; a{0.25h,1w};]
#
#     )
#     #annotate!(0.95, 0.05, text("mytext", :red, :right, 3))
# end
# gif(anim, "gif_final.gif", fps = 6)
#
#
# # p2 = areaplot(A.*4,
# #   dpi = 150,
# #   legend=:outertopright,
# #   fill=clr',
# #   label=lab,
# #   xlims = (1,T),
# #   ylims = (0, 8e4),
# #   xlabel="time [h]",
# #   ylabel="Power [MWh]"
# #   )
# # savefig("Energy_share_real.png") # save the most recent fig as fn
#
#
#
# #
# # x = repeat(rand(1,T),1,F)
# # y = repeat(rand(1,T),1,F)
# #
# # anim = @animate for t ∈ 1:T
# #   areaplot(value.(plant[:,:,1+24*(t-1):24+24*(t-1)]),label=lab,xticks=1:T,ylims=(0,maximum(sum(value.(plant[:,:,1:T]),dims=2))))
# # end
# # gif(anim, "anim_heatmap_test2.gif", fps = 15)
#
# # ============================== 3D PLOT UNIT ACTIVATION ==============================
#
# x = repeat([i for i in 1:N],F*T)
# y = repeat([i for i in 1:F],N*T)
# z = repeat([i for i in 1:T],N*F)
#
# scatter(x,y,z,
#   marker=:cross,
#   marker=:cross,
#
#   color=[])
#
# # ============================== PLOT ==============================
# # Preparing plot with custom labels and colors for nodes and
# Random.seed!(1000)
# edge_labels = ["$(value.(flow)[e]) / $(e.capacity)\n$(round(value.(flow)[e]*100 / e.capacity)) % \$" for e in Edges]
# edge_labels = [ abs(value.(flow)[e]) - 10e-6 > 0 ? "$(round(abs(value.(flow)[e])*100 / e.capacity)) %" : "" for e in Edges]
# edge_labels = [ abs(value.(flow)[e]) - 10e-6 > 0 ? "$(round(abs(value.(flow)[e]),digits=1))\n$(round(abs(value.(flow_to)[e]),digits=1))\n$(round(abs(value.(flow_loss)[e]),digits=1))" : "" for e in Edges]
# edge_colors = []
# node_colors = []
# node_lab = ["$(round(value.(generation[v]) - value.(demand[v]),digits=1))" for v in Verts]
# for v in Verts
#   if v.generation > 0 && v.demand == 0
#     push!(node_colors,"blue")
#     push!(node_lab,"blue")
#   elseif v.generation == 0 && v.demand > 0
#     push!(node_colors,"red")
#   elseif v.generation > 0 && v.demand > 0
#     push!(node_colors,"orange")
#   else
#     push!(node_colors,"turquoise")
#   end
# end
#
# # Graph plot
# g = SimpleGraph(node_max)  # Directional graph: SimpleDiGraph, Undirectional graph: SimpleGraph
#
# # Coloring Edges regarding flow/capacity-ratio.
# for e in Edges
#   val = value.(flow)[e]/e.capacity
#   println(value.(flow)[e])
#   if abs(val) - 10e-6 > 0 && abs(val) < 0.7
#     #push!(edge_colors,"red")
#     push!(edge_colors,RGBA(0,1,0,0.5))
#   elseif abs(val) >= 0.7 && abs(val) < 0.9
#     push!(edge_colors,RGBA(1,1,0,0.5))
#   elseif abs(val) >= 0.9
#     push!(edge_colors,RGBA(1,0,0,0.5))
#   else
#     push!(edge_colors,"lightgrey")
#   end
#
#   # Creating
#   if val >= 0
#     add_edge!(g,e.from,e.to)
#   else
#     add_edge!(g,e.to,e.from)
#   end
# end
#
# #plot(gplot(g,nodelabel=1:node_max,nodefillc=node_colors, edgelabel=edge_labels,edgelabelc="black",edgelabelsize=6,edgestrokec=edge_colors))
# p = gplot(g,
#   nodelabel=node_lab,
#   nodefillc=node_colors,
#   edgestrokec=edge_colors,
#   edgelabel=edge_labels,
#   arrowlengthfrac=0,
#   edgelabelsize=4,
#   nodelabelsize=4,
#   layout=spring_layout
#   )
# #gplot(g,nodelabel=1:30,nodefillc=node_colors, edgelabel=edge_labels,edgelabelc="black",edgelabelsize=6,edgestrokec=edge_colors)
#
# # save file # GraphPlot
# using Cairo, Compose
# draw(PNG("transport_model1.png",16cm,16cm),gplot(g,nodelabel=1:N,nodefillc=node_colors,edgestrokec=edge_colors, edgelabel=edge_labels,arrowlengthfrac=0.05))
#
# # -------------------------- plot funcs --------------------------
#
