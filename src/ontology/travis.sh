# Running the DPO release pipeline for TRAVIS
set -e

sh run.sh make IMP=false pre_release -B

sh run.sh make SRC=dpo-edit-release.owl IMP=false prepare_release -B

sh run.sh make IMP=false flybase_qc -B
