#!/usr/bin/env bash
INPUTDIR="/global/homes/s/sfogarty/2x2_cosmics"
OUTDIR="/pscratch/sd/s/sfogarty/cosmics/single_module"
DET=$1 # 0 for single Bern module, 1 for 2x2
NSHOW=$2 # number of showers generated

if [ "${NSHOW}" = "" ]; then
    NSHOW=2000000
    echo "NSHOW not specified, generating $NSHOW showers"
fi

# set detector and geometry
if [ "${DET}" = "0" ]; then
    DET=0
    GEOMETRY=Module0
elif [ "${DET}" = "1" ]; then
    DET=1
    GEOMETRY=Merged2x2MINERvA_v3_withRock
else
    DET=1
    GEOMETRY=Merged2x2MINERvA_v3_withRock
    echo "DET not specified, using defaults."
fi
echo "DET set to ${DET}, GEOMETRY = ${GEOMETRY}"

# make folders for data in OUTDIR if they don't exist
mkdir -p ${OUTDIR}/corsika
mkdir -p ${OUTDIR}/edep
mkdir -p ${OUTDIR}/h5
mkdir -p ${OUTDIR}/rootracker

DATE=$(date +%s)
SEED=$((${RANDOM}+${DATE}))
RNDSEED=$SEED
RNDSEED2=$SEED
echo "Random seeds are $RNDSEED, $RNDSEED2"

TIME_START=`date +%s`
echo "Setting to CORSIKA-friendly container."
shifter --image=fermilab/fnal-wn-sl7:latest --module=cvmfs -- /bin/bash << EOF1
echo 'Setting up software'
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup edepsim v3_0_1 -q e19:prof
setup corsika
chmod +x run_CORSIKA.sh
./run_CORSIKA.sh $NSHOW $DET $RNDSEED $RNDSEED2 $OUTDIR
EOF1
TIME_CORSIKA=`date +%s`
TIME_A=$((${TIME_CORSIKA}-${TIME_START}))

echo "Setting to GENIE_edep-sim container."
shifter --image=mjkramer/sim2x2:genie_edep.3_04_00.20230620 --module=cvmfs -- /bin/bash << EOF2
set +o posix
source /environment
chmod +x run_edep-sim.sh
source convert.venv/bin/activate
./run_edep-sim.sh $GEOMETRY $RNDSEED $OUTDIR
EOF2
TIME_EDEP=`date +%s`
TIME_B=$((${TIME_EDEP}-${TIME_CORSIKA}))

TIME_STOP=`date +%s`
TIME_TOTAL=$((${TIME_STOP}-${TIME_START}))
echo "Time to run CORSIKA and corsikaConverter = ${TIME_A} seconds"
echo "Time to run edep-sim and h5 converter = ${TIME_B} seconds"
echo "Total time elapsed = ${TIME_TOTAL} seconds"
