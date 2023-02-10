# Running the DPO release pipeline

# Updating and cleaning the imports needs to be done in a separate step.
# This is because the preprocessing step (EDIT_PREPROCESSED) is
# dependent on the imports, but the imports are themselves dependent
# on the pre-processed file.
sh run.sh make PAT=false clean_imports -B

# Now we can run the release pipeline. No need to update the imports again.
sh run.sh make IMP=false prepare_release -B
