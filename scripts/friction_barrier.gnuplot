# ── DATA PROFILE ──────────────────────────────────────────
# python3 scripts/dat_profile.py plots/friction_barrier.dat
#   rows=8 cols=3
#   col 1 (k): 0..7 categorical
#   col 2 (Gamma_k): 0..23
#   col 3 (T_barrier_k, K): 0..4782.7

# ── PARAMETERS (data-driven) ─────────────────────────────
X_MIN = -0.6
X_MAX = 7.6
Y_MIN = 0
Y_MAX = 26
T_MAX = 5300

# ── TERMINAL ─────────────────────────────────────────────
# set terminal dumb size 110,36
set terminal pngcairo enhanced color font "Sans,12" size 1000,650
set output "plots/friction_barrier.png"

# ── AXES ─────────────────────────────────────────────────
set xrange [X_MIN:X_MAX]
set yrange [Y_MIN:Y_MAX]
set y2range [0:T_MAX]
set ytics 0,5,25
set y2tics 0,1000,5000 nomirror
set xtics ("classical" 0, "triad" 1, "intuitionistic" 2, "quantum" 3, \
           "paracons." 4, "5" 5, "6" 6, "7" 7) font "Sans,9"
set ylabel "friction density  Γ_k" offset 1,0
set y2label "T (K)" offset -1,0
set grid ytics ls 0
set style fill solid 0.55 border -1
set boxwidth 0.7 relative

# ── ANNOTATIONS ──────────────────────────────────────────
set arrow from 2,3 to 3,16 nohead lc rgb "#CC3333" lw 2 dashtype 2
set label "associator onset\nΓ_2 = 2  ->  Γ_3 = 19" \
    at 1.55,8.5 left textcolor rgb "#CC3333" font "Sans,10"
set label "associative\nΓ_k = k" at 0.5,21 center textcolor rgb "#888888" font "Sans,9"
set label "non-associative\nΓ_k = k + 16" at 1.0,16.5 center textcolor rgb "#888888" font "Sans,9"

# ── PLOT ─────────────────────────────────────────────────
# all bars steel blue; k=3 (associator onset) red.
plot "plots/friction_barrier.dat" using 1:2 with boxes lc rgb "#4066C8" notitle, \
     "plots/friction_barrier.dat" using (($1==3) ? $1 : 1/0):2 with boxes lc rgb "#CC3333" notitle
