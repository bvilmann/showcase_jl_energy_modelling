using DataFrames
using ExcelFiles
using Plots

#cd("C:\\Users\\Benjamin\\Dropbox\\DTU\\05_03_PROPENS-LP-Julia\\gis\\nuts")
cd("C:\\Users\\Benjamin\\Dropbox\\DTU\\05_03_PROPENS-LP-Julia\\project_master")

# ============================ SOLVE TIME ============================
# Computation time
ctime = load("comp_time.xlsx","Sheet1") |> DataFrame

p = plot(
  convert(Matrix,ctime),
  #label=lab,
  label=permutedims(names(ctime)),
  marker=([:vline :circle :rtriangle :x :d :hex],6),
  line=([:solid :dash :dash :dot :dashdotdot :dashdotdot]),
  yaxis=:log,
  ylabel="Solution time [s]",
  xlabel="Number of timesteps solved for [-]",
  legend=:topleft,
  ylim=(10e-3,10e2),
  dpi=300)

savefig(p,"sol_time.png")

# ============================ GERMANY ============================
# Shape files (NUTS)
using PlotShapefiles
using DBFTables

# data = load("DataTable.xlsx","DataTable") |> DataFrame
# de = innerjoin(test_df2, data, on = :NUTS_CODE)[1:16,:]
# de = sort(de,[:data])
test = open_shapefile("plots/nuts/1000_NUTS1.shp")
test_df = DBFTables.Table("plots/nuts/1000_NUTS1.dbf") # Read DBF file
data = load("data.xlsx","State parameters") |> DataFrame

test_df2 = DataFrame(test_df)           # Convert to DataFrame
test_df2[!, :shapes] = test.shapes      # Add shapes to DataFrame

de = innerjoin(test_df2, data, on = :NUTS_CODE)[1:16,:]
de = sort(de,[:dem_cap])
de[!,:Population] = de[!,:Population]./1000000
de[!,:Capacity] = de[!,:Capacity]./1000

minx = miny = 0
maxx = maxy = 10e10

function plotDE(df,lw=0.02,dpi=100,data=:data,title="",clrbar_title="")
    for i in 1:16
        polygon = df[:,:shapes][i]
        pointz = [(parse(Float64,split(string(p)[17:end-1],",")[1]),parse(Float64,split(string(p)[17:end-1],",")[2])) for p in polygon.points]
        z = df[:,data][i]
        #fillclr = clrschm(z,minimum(df[:,data]),maximum(df[:,data]))
        fillclr = cgrad([:white,:blue],[minimum(df[:,data]),maximum(df[:,data])])

        dminx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[1])
        dminy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[2])
        dmaxx = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[3])
        dmaxy = parse(Float64,split(string(polygon.MBR)[16:end-1],",")[4])

        if i == 1
            if length(polygon.parts) == 1
                global p = plot(Shape(pointz),aspect_ratio=1,legend=:none,colorbar=:best,fill_z = z,linewidth=lw,grid=:none,framestyle=:none,dpi = dpi,c = :blues,colorbar_title=clrbar_title,title=title,colorbar_title_location=:top,bottom_margin=-20px)
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
                        global p = plot(Shape(segments),legend=:none,colorbar=:best,fill_z = z,linewidth=lw,grid=:none,framestyle=:none,dpi = dpi,colorbar_title=clrbar_title,c = :blues,title=title,colorbar_title_location=:top,bottom_margin=-30px)
                    else
                        plot!(Shape(segments),fill_z = z,linewidth=lw,legend=:none,colorbar=:best,c = :blues)
                    end
                    cnt = idx + 1
                end
                segments = Tuple{Float64, Float64}[]
                for point in pointz[cnt:finish]
                    push!(segments,(point[1],point[2]))
                end
                plot!(Shape(segments),fill_z = z,linewidth=lw,legend=:none,colorbar=:best,c = :blues)
            end
        else
            if length(polygon.parts) == 1
                plot!(Shape(pointz),fill_z = z,aspect_ratio=1,legend=:none,colorbar=:best,linewidth=lw,c = :blues)
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
                    plot!(Shape(segments),fill_z = z,legend=:none,colorbar=:best,linewidth=lw,c = :blues)
                    cnt = idx + 1
                end
                segments = Tuple{Float64, Float64}[]
                for point in pointz[cnt:finish]
                    push!(segments,(point[1],point[2]))
                end
                plot!(Shape(segments),fill_z = z,legend=:none,colorbar=:best,linewidth=lw,c = :blues)
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
    return p
end

# plotDE(df,linewidth,dpi)
lw = 0.2
dpi = 150
pyplot()
p1 = plotDE(de,lw,dpi,:Population,"Population","Mil.")
p2 = plotDE(de,lw,dpi,:Capacity,"Capacity","GW")
p3 = plotDE(de,lw,dpi,:dem_cap,"demand / capacity","[-]")
p4 = plotDE(de,lw,dpi,:alpha,"α (RES share)","[-]")
p5 = plotDE(de,lw,dpi,:beta,"β (Wind share of RES)","[-]")
p6 = plotDE(de,0.2,150,:tCO2_s,"Potential CO2 emissions","tCO2/s")

deplot = plot(
    p1,p2,p3,p4,p5,p6,
    size = (1600, 1200),
    dpi=300,
    bottommargin=20px,
    rightmargin=50px,
    layout = grid(2, 3, heights = [0.5,0.5], widths = [0.333,0.333,0.333])
    )

savefig(deplot,"model_germany.png")


# ============================ Plots ============================
# Computation time
# val = rand(3)
# vals2 = rand(3,3)
# cats = ["$(i)" for i in 1:3]
using Plots
ax1 = pie(1:3,title="Pie")
ax3 = plot(rand(3,3),title="Line")
ax2 = bar(1:3,title="Bar")
ax4 = scatter(rand(3,3),title="Scatter")
p = plot(ax1,ax2,ax3,ax4,layout = grid(2, 2, heights = [0.5,0.5], widths = [0.5,0.5]))

savefig(p,"plots_show.png")

# ============================ MAKIE ============================
# BACKENDS: (GLMakie, CairoMakie, WGLMakie)


using CairoMakie
using AbstractPlotting
AbstractPlotting.inline!(true)
scene, layout = layoutscene(30)
ax1 = layout[1, 1] = LAxis(scene,title="Pie")
pie!(ax1,[i for i in 1:3])
ax2 = layout[2, 1] = LAxis(scene,title="Line")
lines!(ax2,rand(3))
lines!(ax2,rand(3))
lines!(ax2,rand(3))
ax3 = layout[1, 2] = LAxis(scene,title="Bar")
# Bar plot is not possible
ax4 = layout[2, 2] = LAxis(scene,title="Scatter")
scatter!(ax4,rand(3))
scatter!(ax4,rand(3))
scatter!(ax4,rand(3))

scene

save("makie_show.png", scene)
