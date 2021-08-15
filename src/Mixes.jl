module Mixes

export µM, nM, µL, nmol, pmol

export Comp, Mix, show, to_table

using Unitful
import Markdown

µM = u"µM";
nM = u"nM";
µL = u"µL";
nmol = u"nmol"
pmol = u"pmol"


"""
A specified component.  Final may be a concentration (for a fixed final concentration),
a real number (for multiples of some base concentration to be calculated by components),
or a volume (to fix the volume, also setting concentration to the base concentration of the mix).
"""
struct Comp{T} 
    name::String
    baseconc::Unitful.Molarity
    final::T
    number::Int
end
Comp(name, baseconc, final) = Comp(name, baseconc, final, 1)

implied_unit_amount(c::Comp{<:Real}) = nothing
implied_unit_amount(c::Comp{<:Unitful.Volume}) = c.final * c.baseconc
implied_unit_amount(c::Comp{<:Unitful.Molarity}) = nothing

each_volume(c::Comp{<:Real}; mix_volume=nothing, set_unit_amount=nothing) = 
    (c.final * set_unit_amount / c.baseconc) |> µL
function each_volume(c::Comp{<:Unitful.Volume}; mix_volume=nothing, 
        set_unit_amount=nothing) 
    @assert set_unit_amount == implied_unit_amount(c)
    @assert c.final == (set_unit_amount / c.baseconc) |> µL
    c.final
end

each_volume(c::Comp{<:Unitful.Molarity}; mix_volume::Unitful.Volume, 
    set_unit_amount=nothing) =
    mix_volume * (c.final / c.baseconc) |> µL

total_volume(c::Comp; mix_volume=nothing, set_unit_amount=nothing) = 
    c.number * each_volume(c, mix_volume=mix_volume, set_unit_amount=set_unit_amount)

struct Mix
    name::String
    conc
    volume
    comps::Vector{Comp}
    buffer
end

Mix(name, conc, volume, comps; buffer="buffer") = Mix(name, conc, volume, comps, buffer)

function unit_amount(m::Mix)
    if typeof(m.comps[1].final) <: Unitful.Molarity
        nothing
    elseif m.volume !== nothing # set via total volume
        tqv = 0.0µL / nmol
        for c in m.comps
            tqv += m.final * m.number / m.baseconc
        end
        m.volume / tqv |> pmol
    else
        qconts = map(c -> implied_unit_amount(c), m.comps) |> x -> filter(y -> y !== nothing, x)
        @assert all(x -> x == qconts[1], qconts)
        qconts[1] |> pmol
    end
end

function volume(m::Mix)
    if m.volume !== nothing  # This is easy
        m.volume
    else
        # There should be at least one component with a volume,
        # and that volume sets the unit quantity.  Then, we need
        # to calculate how much total volume is needed to get that
        # quantity. 
        uq = unit_amount(m)
        sum(total_volume(c; set_unit_amount=uq) for c in m.comps)
    end
end
struct ConcreteComp
    name
    baseconc
    number
    eachvolume
end

struct ConcreteMix
    name
    conc
    comps::Vector{ConcreteComp}
end

total_volume(c::ConcreteComp) = c.number * c.eachvolume
function final_conc(c::ConcreteComp, mix_vol)
    if c.baseconc != ""
        c.baseconc * (c.eachvolume / mix_vol)
    else
        ""
    end
end


function concrete(m::Mix)
    vol = volume(m)
    ua = unit_amount(m)
    
    cs = Vector{ConcreteComp}()
    usedvol = 0.0µL
    for c in m.comps
        cc = ConcreteComp(c.name, c.baseconc, c.number, 
            each_volume(c; mix_volume=vol, set_unit_amount=ua))
        push!(cs, cc)
        usedvol += total_volume(c; mix_volume=vol, set_unit_amount=ua)
    end
    if usedvol != vol
        push!(cs, ConcreteComp(m.buffer, "", 1, vol - usedvol))
    end
    return ConcreteMix(m.name, m.conc, cs)
end

function total_volume(m::ConcreteMix)
    sum(total_volume(x) for x in m.comps)
end

function to_table(m::ConcreteMix)
    showeach = any(c.number > 1 for c in m.comps)
    totvol = total_volume(m)
    
    if !showeach
        header = [["Name", "Init[]", "Final[]", "Vol"]]
        cs = [[x.name, x.baseconc, final_conc(x, totvol), x.eachvolume] for x in m.comps]
        align = [:l, :r, :r, :r]
    else
        header = [["Name", "Init[]", "Final[]", "#", "Vol ea.", "Vol tot."]]
        cs = [[x.name, x.baseconc, final_conc(x, totvol), x.number, 
                x.eachvolume, total_volume(x)] for x in m.comps]
        align = [:l, :r, :r, :r, :r, :r, :r]
    end
    Markdown.MD([
            Markdown.Paragraph("Table: Mix $(m.name), $(totvol) @ $(m.conc)"),
            Markdown.Table(vcat(header, cs), align)
            ])
end

to_table(m::Mix) = m |> concrete |> to_table

Base.show(io::IO, mix::Mix) = show(io, mix |> to_table)

end