#!/bin/sh

#OAR -l nodes=1,walltime=3
#OAR -p cluster='graphite'
#OAR -t deploy

if [ "$1" = "--submit" ]; then
  scp ./snapshot.sh "$2": &&
  ssh "$2" chmod u+x "./snapshot.sh" &&
  ssh "$2" oarsub -S ./snapshot.sh
  exit $?
fi

if [ -n "$OAR_NODE_FILE" ]; then
  kadeploy3 -e jessie-x64-min -k ~/.ssh/authorized_keys -f $OAR_NODE_FILE >&2 &&
  node="$(cat "$OAR_NODE_FILE" | uniq | head -n1)" &&
  scp ./snapshot.sh "root@$node": >&2 &&
  ssh root@$node chmod u+x ./snapshot.sh >&2 &&
  exec ssh root@$node ./snapshot.sh ||
  exit 1
fi

echo "* Prepare the environment"

echo "** Install packages"
DEBIAN_FRONTEND=noninteractive ; export DEBIAN_FRONTEND
apt-get update >&2
apt-get install --no-install-recommends --no-install-suggests -y \
  lsb-release time \
  gcc g++ git cmake cmake-curses-gui make \
  libboost-dev libboost-context-dev \
  libdw-dev libunwind-dev \
  >&2
# Ideally, one would like to do a reboot here. In order to do this we'd have
# to move this into the deployment section.

echo "** Machine information"
LANG=C
date
uname -a
lsb_release -idrc
cat /proc/cpuinfo | grep "model name"
cat /proc/meminfo | grep ^Mem
for prog in cc c++ git make cmake; do
  "$prog" --version | head -n1
done
free

echo "** Package list"
dpkg -l | grep ^[a-z] | awk '{print $1, $2, $3, $4}'

echo "** Install SimGrid"
set -e
cd
git config --global http.proxy http://proxy:3128
if [ -d simgrid ]; then
  cd simgrid
  git fetch >&2
  git reset --hard >&2
else
  git clone https://github.com/mquinson/simgrid.git >&2
  cd simgrid
fi
git checkout origin/snapshot-xp2 >&2
cmake . \
  -Denable_compile_optimizations=ON -Denable_compile_warnings=ON -Denable_model-checking=ON \
  -Denable_smpi=ON -Denable_smpi_MPICH3_testsuite=ON -Denable_smpi_ISP_testsuite=OFF \
  -Denable_documentation=OFF \
  >&2
make clean >&2
make -j"$(nproc || echo 1)" >&2

echo "* Experiments"

SIMGRID_MC_SYSTEM_STATISTICS=free
export SIMGRID_MC_SYSTEM_STATISTICS

runxp() {
  test=$1
  np=$2
  name=$3
  shift
  shift
  shift
  echo "*** XP $(basename $test) NP=$np $name"
  /usr/bin/time -f "clock:%e user:%U sys:%S swapped:%W exitval:%x max:%Mk" \
    bin/smpirun \
    -wrapper "bin/simgrid-mc" \
    -np "$np" \
    -hostfile ./teshsuite/smpi/hostfile_coll \
    -platform ./examples/platforms/small_platform_with_routers.xml \
    --cfg=contexts/factory:ucontext --cfg=contexts/stack_size:16 \
    --cfg=smpi/coll_selector:mpich --cfg=smpi/running_power:1e9 --cfg=smpi/send_is_detached_thres:0 \
    --cfg=model-check/max_depth:100000 \
    --cfg=model-check/reduction:none --cfg=model-check/visited:1000000 \
    "$@" "$test" 2>&1 |
    grep -v -e "^ No Errors" -e "xbt_cfg/INFO" -e surf_config/INFO ||
    true
}

setup_ksm() {
  echo 1 > /sys/kernel/mm/ksm/run &&
  echo 10000 > /sys/kernel/mm/ksm/pages_to_scan
}

runxps() {
  test="$1"
  np="$2"
  echo "** XP $(basename $1) $np"
  shift
  shift

  runxp "$test" "$np" "plain" --cfg=model-check/sparse-checkpoint:no --cfg=model-check/ksm:0 --cfg=model-check/soft-dirty:0 "$@"
  setup_ksm || exit 1
  runxp "$test" "$np" "KSM" --cfg=model-check/sparse-checkpoint:no --cfg=model-check/ksm:1 --cfg=model-check/soft-dirty:0 "$@"
  runxp "$test" "$np" "page" --cfg=model-check/sparse-checkpoint:yes --cfg=model-check/ksm:1 --cfg=model-check/soft-dirty:0 "$@"
  runxp "$test" "$np" "page+soft" --cfg=model-check/sparse-checkpoint:yes --cfg=model-check/ksm:1 --cfg=model-check/soft-dirty:1 "$@"
}

runxps teshsuite/smpi/mpich3-test/comm/dup 2
runxps teshsuite/smpi/mpich3-test/comm/dup 3
runxps teshsuite/smpi/mpich3-test/comm/dup 4

runxps teshsuite/smpi/mpich3-test/group/groupcreate 2
runxps teshsuite/smpi/mpich3-test/group/groupcreate 3
runxps teshsuite/smpi/mpich3-test/group/groupcreate 4
# runxps teshsuite/smpi/mpich3-test/group/groupcreate 5
# runxps teshsuite/smpi/mpich3-test/group/groupcreate 6

runxps teshsuite/smpi/mpich3-test/pt2pt/sendrecv2 2

runxps teshsuite/smpi/mpich3-test/coll/op_commutative 3
runxps teshsuite/smpi/mpich3-test/coll/op_commutative 4
runxps teshsuite/smpi/mpich3-test/coll/op_commutative 5
