#!/usr/bin/env bash
# Collect the steady-state integral loads of every pitch_* case and convert
# them to lift/drag/moment and CL/CD/CM.
#
# Usage: ./collect_loads.sh [-n NAVG] [-o out.csv] [-l loadfile]
#   -n NAVG  average the last NAVG rows of the load history (default 1 = last row)
#   -o FILE  CSV output (default: loads_summary.csv)
#   -l FILE  load file relative to the case dir (default: Postprocess/naca0012_wing_load01.dat)
#
# Everything is read from the case files, nothing is hardcoded:
#   u_inf, rho_inf  <- pitch_N/dust.in           (rho_inf default 1.225 if commented out)
#   chord, span     <- pitch_N/Geometry/wing.in  (span doubled if mesh_symmetry = T)
#
# Conventions (loads file is in the WingRef frame: x aft, y span, z up):
#   alpha = atan(uz/ux) from u_inf
#   L = -Fx sin(a) + Fz cos(a)      D = Fx cos(a) + Fz sin(a)
#   M = My (about the WingRef origin, i.e. the leading edge), positive nose-up
#   CL = L/(q S), CD = D/(q S), CM = M/(q S c),  q = 0.5 rho U^2, S = chord * full span

set -euo pipefail
cd "$(dirname "$0")"

navg=1
out=loads_summary.csv
loadfile=Postprocess/naca0012_wing_load01.dat
while getopts "n:o:l:" opt; do
  case $opt in
    n) navg=$OPTARG ;;
    o) out=$OPTARG ;;
    l) loadfile=$OPTARG ;;
    *) echo "usage: $0 [-n NAVG] [-o out.csv] [-l loadfile]" >&2; exit 1 ;;
  esac
done

# value of an uncommented "key = value" line (first match), comments stripped
getval() { sed -E 's/!.*//' "$2" | awk -F= -v k="$1" '$1 ~ "^[ \t]*"k"[ \t]*$" {print $2; exit}'; }

echo "pitch,alpha_deg,U,rho,S,c,Fx,Fy,Fz,Mx,My,Mz,L,D,M,CL,CD,CM" > "$out"

for dir in $(ls -d pitch_* | sort -t_ -k2 -n); do
  pitch=${dir#pitch_}
  dat=$dir/$loadfile
  if [[ ! -s $dat ]]; then echo "skip $dir: $dat not found" >&2; continue; fi

  uinf=$(getval u_inf "$dir/dust.in" | tr -d '(/) ' )
  rho=$(getval rho_inf "$dir/dust.in"); rho=${rho:-1.225}
  chord=$(getval chord "$dir/Geometry/wing.in" | head -1)
  span=$(sed -E 's/!.*//' "$dir/Geometry/wing.in" | awk -F= '$1 ~ /^[ \t]*span[ \t]*$/ {s+=$2} END {print s}')
  sym=$(getval mesh_symmetry "$dir/Geometry/wing.in" | tr -d ' ')
  [[ $sym == T || $sym == .true. ]] && span=$(awk -v s="$span" 'BEGIN {print 2*s}')

  # data rows only (skip '#' header), take the last navg rows and average them
  grep -E '^[[:space:]]*[0-9]' "$dat" | tail -n "$navg" | awk -v pitch="$pitch" -v uinf="$uinf" \
    -v rho="$rho" -v c="$chord" -v b="$span" -v OFS=, '
    BEGIN { split(uinf, u, ","); pi = atan2(0, -1) }
    { for (i = 2; i <= 7; i++) s[i] += $i; n++ }
    END {
      for (i = 2; i <= 7; i++) s[i] /= n
      Fx = s[2]; Fy = s[3]; Fz = s[4]; Mx = s[5]; My = s[6]; Mz = s[7]
      U = sqrt(u[1]^2 + u[2]^2 + u[3]^2); a = atan2(u[3], u[1])
      S = c * b; q = 0.5 * rho * U^2
      L = -Fx * sin(a) + Fz * cos(a); D = Fx * cos(a) + Fz * sin(a)
      printf "%s,%.4f,%.4f,%.4f,%.5f,%.5f,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6f,%.6f,%.6f\n", \
        pitch, a * 180 / pi, U, rho, S, c, Fx, Fy, Fz, Mx, My, Mz, L, D, My, L / (q * S), D / (q * S), My / (q * S * c)
    }' >> "$out"
done

column -s, -t "$out"
echo "-> $out (averaged over last $navg row(s))"
