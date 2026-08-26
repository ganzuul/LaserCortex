# ── DATA PROFILE ──────────────────────────────────────────
# python3 scripts/dat_profile.py plots/lightcone_census.dat
#   rows=5 cols=5
#   col 1 (cd): 0..4 categorical
#   col 2 (gamma): 0..20
#   col 3 (spacelike): 0..132
#   col 4 (lightlike): 0..14
#   col 5 (timelike): 0..131

# ── PARAMETERS (data-driven) ─────────────────────────────
X_MIN = -0.6
X_MAX = 4.6
Y_MIN = 0
Y_MAX = 145

# ── TERMINAL ─────────────────────────────────────────────
# set terminal dumb size 90,32
set terminal pngcairo enhanced color font "Sans,12" size 1000,650
set output "plots/lightcone_census.png"

# ── AXES ─────────────────────────────────────────────────
set xrange [X_MIN:X_MAX]
set yrange [Y_MIN:Y_MAX]
set ytics 0,25,150
set xtics ("classical\n(Γ=0)" 0, "triad\n(Γ=1)" 1, "intuitionistic\n(Γ=2)" 2, \
           "quantum\n(Γ=19)" 3, "paracons.\n(Γ=20)" 4) font "Sans,9"
set ylabel "size-6 routes (count)" offset 1,0
set grid ytics ls 0
set style fill solid 0.55 border -1
set boxwidth 0.6 relative

# ── LEGEND ───────────────────────────────────────────────
set key at graph 0.02,0.98 left top spacing 1.2 font "Sans,10"

# ── ANNOTATIONS ──────────────────────────────────────────
set arrow from 2,60 to 3,132 nohead lc rgb "#CC3333" lw 2 dashtype 2
set label "lightcone inversion:\nall routes spacelike" \
    at 2.7,75 center textcolor rgb "#CC3333" font "Sans,10"

# ── PLOT ─────────────────────────────────────────────────
# stacked: spacelike (bottom), lightlike (middle), timelike (top)
plot "plots/lightcone_census.dat" using 1:3 with boxes lc rgb "#4066C8" title "spacelike", \
     "plots/lightcone_census.dat" using 1:($3+$4) with boxes lc rgb "#888888" title "lightlike", \
     "plots/lightcone_census.dat" using 1:($3+$4+$5) with boxes lc rgb "#CC3333" title "timelike"
