set terminal qt size 1024, 800 position 100, 100 noraise
set xrange [-100:100];
set yrange [-100:100];
set zrange [-100:100];
set xyplane at 0;
unset xtics;
unset ytics;
unset ztics;
set zzeroaxis linetype 0;
set xzeroaxis linetype 0;
set yzeroaxis linetype 0;
set view 60, 30, 1, 1;
unset border;
splot 'frame.txt' using 1:2:3:4 with labels notitle
pause 0.016
reread
