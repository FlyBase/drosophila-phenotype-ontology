## Customize Makefile settings for dpo
##
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

# Using .SECONDEXPANSION to include custom FlyBase files in $(ASSETS). Also rsyncing $(IMPORTS) and $(REPORT_FILES).
.SECONDEXPANSION:
.PHONY: prepare_release
prepare_release: $$(ASSETS) release_reports
	rsync -R $(RELEASE_ASSETS) $(REPORT_FILES) $(FLYBASE_REPORTS) $(IMPORT_FILES) $(RELEASEDIR) &&\
	mkdir -p $(RELEASEDIR)/patterns && cp -rf $(PATTERN_RELEASE_FILES) $(RELEASEDIR)/patterns &&\
	rm -f $(CLEANFILES)
	echo "Release files are now in $(RELEASEDIR) - now you should commit, push and make a release on your git hosting site such as GitHub or GitLab"

CLEANFILES := $(CLEANFILES) $(patsubst %, $(IMPORTDIR)/%_terms_combined.txt, $(IMPORTS))

tmp/all_patternised_classes.txt:
	$(ROBOT) query --use-graphs false -f csv -i $(PATTERNDIR)/definitions.owl --query ../sparql/dpo-equivalent-classes.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

tmp/all_defined_classes.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-equivalent-classes.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

tmp/remaining_classes.txt: tmp/all_patternised_classes.txt tmp/all_defined_classes.txt
	comm -13 $^ > $@

tmp/remaining_definitions.owl: $(SRC) tmp/remaining_classes.txt
	$(ROBOT) filter -i $< -T tmp/remaining_classes.txt --axioms "equivalent annotation" --trim false -o $@

##################################
##### Custom mirroring rules #####
##################################

# FBdv defines "shorthands" for some RO relations, which leads to
# "duplicate label" violations. In theory we could use 'make_base' to
# automatically get rid of those duplicated labels, but doing so has the
# the side-effect of removing the "Transitive" characteristic on
# FBdv:0018001, which in turn prevents the correct classification of
# lethal terms.
# So here, we take a softer approach, in which we simply remove from
# FBdv's base the annotations on the RO relations for which we have
# defined shorthands.
# (Whether it is a good idea to have those shorthands defined in FBdv
#  in the first place is another question.)
mirror-fbdv: | $(TMPDIR)
	if [ $(MIR) = true ] && [ $(IMP) = true ]; then \
		curl -L $(OBOBASE)/fbdv/fbdv-base.owl --create-dirs \
		  -o $(TMPDIR)/fbdv.owl --retry 4 --max-time 200 && \
		$(ROBOT) remove -i $(TMPDIR)/fbdv.owl \
		  --term RO:0002087 --term RO:0002090 \
		  --term RO:0002092 --axioms annotation \
		  convert -o $@.tmp.owl && mv $@.tmp.owl $(TMPDIR)/$@.owl; fi


#######################################################
##### Code for removing patternised classes ###########
#######################################################

patternised_classes.txt: .FORCE
	$(ROBOT) query -f csv -i ../patterns/definitions.owl --query ../sparql/dpo_terms.sparql $@
	sed -i 's/http[:][/][/]purl.obolibrary.org[/]obo[/]//g' $@
	sed -i '/^[^F]/d' $@

remove_patternised_classes: $(SRC) patternised_classes.txt
	sed -i -r "/^EquivalentClasses[(].*($(shell cat patternised_classes.txt | xargs | sed -e 's/ /\|/g'))/d" $<

######################################################
### Overwriting some default artefacts ###
######################################################

# Simple is overwritten to strip out duplicate names and definitions.
$(ONT)-simple.obo: $(ONT)-simple.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

# We want the OBO release to be based on the simple release. It needs to be annotated however in the way map releases (fbbt.owl) are annotated.
$(ONT).obo: $(ONT)-simple.owl
	$(ROBOT)  annotate --input $< --ontology-iri $(URIBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY) \
	convert --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	cat $@.tmp.obo | grep -v ^owl-axioms > $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

############################################################
### Code for generating class hierarchy for lethal terms ###
############################################################

$(TMPDIR)/lethal_terms.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query $(SPARQLDIR)/dpo-lethal.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

$(TMPDIR)/lethal_extract.owx: $(SRC) $(TMPDIR)/lethal_terms.txt
	grep -v "lethal_class_hierarchy.owl" $< > $(TMPDIR)/dpo-tmp.ofn &&\
	grep -v "lethal_class_hierarchy.owl" catalog-v001.xml > catalog-tmp.xml &&\
	robot --catalog catalog-tmp.xml merge --input $(TMPDIR)/dpo-tmp.ofn \
	remove --select "UBERON:* CHEBI:* GO:*" \
	extract --term-file $(TMPDIR)/lethal_terms.txt --force true --method STAR \
	convert --output $@ &&\
	rm catalog-tmp.xml $(TMPDIR)/dpo-tmp.ofn

$(COMPONENTSDIR)/lethal_class_hierarchy.owl: $(TMPDIR)/lethal_extract.owx $(TMPDIR)/lethal_terms.txt
	Konclude classification -i $< -o $(TMPDIR)/konclude-edit.owx &&\
	$(ROBOT) filter -i $(TMPDIR)/konclude-edit.owx -T $(TMPDIR)/lethal_terms.txt --trim false \
	annotate --ontology-iri $(ONTBASE)/$@ --output $@ &&\
	rm $< $(TMPDIR)/konclude-edit.owx

######################################################
### Code for generating additional FlyBase reports ###
######################################################

FLYBASE_REPORTS = reports/obo_qc_dpo.obo.txt reports/obo_qc_dpo.owl.txt reports/obo_track_new_simple.txt reports/robot_simple_diff.txt reports/onto_metrics_calc.txt reports/chado_load_check_simple.txt

.PHONY: flybase_reports
flybase_reports: $(FLYBASE_REPORTS)

.PHONY: all_reports
all_reports: custom_reports robot_reports flybase_reports

.PHONY: release_reports
release_reports: robot_reports flybase_reports

SIMPLE_PURL = http://purl.obolibrary.org/obo/dpo/dpo-simple.obo
LAST_DEPLOYED_SIMPLE=tmp/$(ONT)-simple-last.obo

$(LAST_DEPLOYED_SIMPLE):
	wget -O $@ $(SIMPLE_PURL)

obo_model=https://raw.githubusercontent.com/FlyBase/flybase-controlled-vocabulary/master/external_tools/perl_modules/releases/OboModel.pm
flybase_script_base=https://raw.githubusercontent.com/FlyBase/drosophila-anatomy-developmental-ontology/master/tools/release_and_checking_scripts/releases/
onto_metrics_calc=$(flybase_script_base)onto_metrics_calc.pl
chado_load_checks=$(flybase_script_base)chado_load_checks.pl
obo_track_new=$(flybase_script_base)obo_track_new.pl
auto_def_sub=$(flybase_script_base)auto_def_sub.pl

export PERL5LIB := ${realpath ../scripts}
install_flybase_scripts:
	wget -O ../scripts/OboModel.pm $(obo_model)
	wget -O ../scripts/onto_metrics_calc.pl $(onto_metrics_calc) && chmod +x ../scripts/onto_metrics_calc.pl
	wget -O ../scripts/chado_load_checks.pl $(chado_load_checks) && chmod +x ../scripts/chado_load_checks.pl
	wget -O ../scripts/obo_track_new.pl $(obo_track_new) && chmod +x ../scripts/obo_track_new.pl
	wget -O ../scripts/auto_def_sub.pl $(auto_def_sub) && chmod +x ../scripts/auto_def_sub.pl

reports/obo_track_new_simple.txt: $(LAST_DEPLOYED_SIMPLE) install_flybase_scripts $(ONT)-simple.obo
	echo "Comparing with: "$(SIMPLE_PURL) && ../scripts/obo_track_new.pl $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo > $@

reports/robot_simple_diff.txt: $(ONT)-simple.obo $(LAST_DEPLOYED_SIMPLE)
	$(ROBOT) diff --left $(ONT)-simple.obo --right $(LAST_DEPLOYED_SIMPLE) --output $@

reports/onto_metrics_calc.txt: $(ONT)-simple.obo install_flybase_scripts
	../scripts/onto_metrics_calc.pl 'phenotypic_class' $(ONT)-simple.obo > $@

reports/chado_load_check_simple.txt: $(ONT)-simple.obo install_flybase_scripts
	apt-get install -y --no-install-recommends libbusiness-isbn-perl
	../scripts/chado_load_checks.pl $(ONT)-simple.obo > $@

reports/obo_qc_%.obo.txt:
	$(ROBOT) report -i $*.obo --profile qc-profile.txt --fail-on ERROR --print 5 -o $@

reports/obo_qc_%.owl.txt:
	$(ROBOT) report -i $*.owl --profile qc-profile.txt --fail-on ERROR --print 5 -o $@

#####################################################################################
### Regenerate placeholder definitions                                            ###
#####################################################################################
# There are two types of definitions that FB ontologies use: "." (DOT-) definitions are those for which the formal
# definition is translated into a human readable definitions (not used in dpo). "$sub_" (SUB-) definitions are those that have
# special placeholder string to substitute in definitions from external ontologies, mostly GO
# dpo only uses SUB definitions - to use DOT, copy code and sparql from FBcv.

export ROBOT_PLUGINS_DIRECTORY = $(TMPDIR)/plugins

$(ROBOT_PLUGINS_DIRECTORY)/flybase.jar:
	mkdir -p $(ROBOT_PLUGINS_DIRECTORY)
	curl -L -o $@ https://github.com/FlyBase/flybase-robot-plugin/releases/download/flybase-robot-plugin-0.1.0/flybase.jar

$(EDIT_PREPROCESSED): $(SRC) $(ROBOT_PLUGINS_DIRECTORY)/flybase.jar
	$(ROBOT) flybase:rewrite-def -i $< --sub-definitions --filter-prefix FBcv -o $@
