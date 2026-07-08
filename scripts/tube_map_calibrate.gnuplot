# tube_map_calibrate.gnuplot — render the calibrated tube map
# Output: plots/tube_map_calibrate.pdf (multi-panel)
#
# Usage:
#   cd <repo-root>
#   python3 scripts/tube_map_calibrate.py
#   gnuplot scripts/tube_map_calibrate.gnuplot

set terminal pdfcairo enhanced color font "DejaVu Sans,10" size 10,8
set output "plots/tube_map_calibrate.pdf"

set style data points
set style fill solid 0.8

# ─── Panel layout ─────────────────────────────────────────────────────
set multiplot layout 2,2 margins 0.08,0.98,0.08,0.95 spacing 0.10,0.10

# ══════════════════════════════════════════════════════════════════════
# PANEL 1: Size 3 — cd=0 (associative) vs cd=3 (non-associative)
# ══════════════════════════════════════════════════════════════════════
set title "Tamari Lattice T₃ — Associative (cd≤2) vs Non-associative (cd=3)"
set xlabel "x = size + assocDefect(cd)"
set ylabel "y = leftWeight − rightWeight"
set xrange [0:9]
set yrange [-4:4]
set xtics 1
set ytics 1
set grid xtics ytics lc rgb "#dddddd"
set key top left

# cd=0 (blue), cd=3 (red)
plot "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::0::4 with points pt 7 ps 2.5 lc rgb "#3366cc" title "cd=0 (associative)", \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::5::9 with points pt 7 ps 2.5 lc rgb "#cc3333" title "cd=3 (non-associative)", \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::10::14 with points pt 7 ps 2.5 lc rgb "#3366cc" notitle, \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::15::19 with points pt 7 ps 2.5 lc rgb "#cc3333" notitle, \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:2 every ::0::4 with labels offset 1,0.5 font ",8" tc rgb "#3366cc" notitle, \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:2 every ::5::9 with labels offset 1,0.5 font ",8" tc rgb "#cc3333" notitle

# ══════════════════════════════════════════════════════════════════════
# PANEL 2: Size 3 lattice at cd=3 with contracts_one edges
# ══════════════════════════════════════════════════════════════════════
set title "Tamari Lattice T₃ at cd=3 — Contraction Graph"
set xlabel "x = size + assocDefect(3) = 7"
set ylabel "y = leftWeight − rightWeight"
set xrange [4:10]
set yrange [-4:4]
set xtics ("7" 7)
set ytics -3,1,3
set grid ytics lc rgb "#dddddd"
set key top left

# Edge arrows
plot "plots/tube_edges_s3.dat" \
     using 1:2:($3-$1):($4-$2) with vectors \
     head size 0.12,20,60 filled lc rgb "#888888" lw 1.5 notitle, \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::5::9 with points pt 7 ps 3.0 lc rgb "#cc3333" notitle, \
     "plots/tube_calibrate_s3.dat" \
     using 7:8:2 every ::5::9 with labels offset 0,-1.2 font ",7" tc rgb "#333333" notitle

# ══════════════════════════════════════════════════════════════════════
# PANEL 3: Size 4 lattice at cd=3
# ══════════════════════════════════════════════════════════════════════
set title "Tamari Lattice T₄ at cd=3 — 14 trees"
set xlabel "x = size + assocDefect(3) = 8"
set ylabel "y = leftWeight − rightWeight"
set xrange [5:11]
set yrange [-7:7]
set xtics ("8" 8)
set ytics -6,2,6
set grid ytics lc rgb "#dddddd"
set key off

plot "plots/tube_edges_s4.dat" \
     using 1:2:($3-$1):($4-$2) with vectors \
     head size 0.10,20,60 filled lc rgb "#888888" lw 1.0 notitle, \
     "plots/tube_calibrate_s4.dat" \
     using 7:8:(0) every ::14::27 with points pt 7 ps 2.5 lc rgb "#33aa33" notitle, \
     "plots/tube_calibrate_s4.dat" \
     using 7:8:2 every ::14::27 with labels offset 0,-1.0 font ",6" tc rgb "#333333" notitle

# ══════════════════════════════════════════════════════════════════════
# PANEL 4: QI protocol path at cd=3
# ══════════════════════════════════════════════════════════════════════
set title "QI Protocol Path — Balanced Tree → rightComb(3) at cd=3"
set xlabel "x = size + assocDefect(3) = 7"
set ylabel "y = leftWeight − rightWeight"
set xrange [4:10]
set yrange [-4:4]
set xtics ("7" 7)
set ytics -3,1,3
set grid ytics lc rgb "#dddddd"
set key top left

# Plot: all trees in grey, path in red with arrows
plot "plots/tube_calibrate_s3.dat" \
     using 7:8:(0) every ::5::9 with points pt 7 ps 3.0 lc rgb "#cccccc" notitle, \
     "plots/tube_qe_path_s3.dat" \
     using 2:3:(0) with points pt 9 ps 3.0 lc rgb "#cc3333" title "path", \
     "plots/tube_qe_path_s3.dat" \
     using 2:3:1 with labels offset 0,-1.2 font ",8" tc rgb "#333333" notitle

unset multiplot

print "Written plots/tube_map_calibrate.pdf"
