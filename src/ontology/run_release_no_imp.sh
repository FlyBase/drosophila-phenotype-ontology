# Running the DPO release pipeline
set -e
# 0. If this is the first time this is run
# sh run.sh make all_imports
# 1. First, lets make sure the ODK is up to date (I comment this out because I use even newer version)
#docker pull obolibrary/odkfull

# 2. Next lets run the preprocessing. This involves creating creating the definitions (essentially substitution of the ones containing the $sub_GO:001 macro)
# This process results in an updated source file dpo-edit-release.owl
sh run.sh make IMP=false pre_release -B

# 3. Now lets run the proper release. Note that here, we are overwriting the SRC variable to be the newly created dpo-edit-release.owl
# This process generates everything from the simple and basic releases to the various flybase reports
# All deviations from the standard OBO process can be found in the dpo.Makefile file
sh run.sh make SRC=dpo-edit-release.owl IMP=false prepare_release -B
