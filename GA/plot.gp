set yrange [3000:4500]
set xrange [3000:4500]
set ylabel 'knapsack1'
set xlabel 'knapsack2'
set style line 1 pointtype 7
plot 'output.dat' linestyle 1

reread
