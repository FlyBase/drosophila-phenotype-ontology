## Customize Makefile settings for dpo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile
#FBDVPURL=http://purl.obolibrary.org/obo/FBdv_
#OTHER_SRC:= $(OTHER_SRC) components/lethal_class_hierarchy.owl

#imports/fbdv_filter_seed.txt: $(SRC) #$(ONTOLOGYTERMS) #prepare_patterns
#	$(ROBOT) query --use-graphs true -f csv -i $< --query ../sparql/object-properties.sparql $@_prop.tmp &&\
#	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/terms.sparql $@_fbdv.tmp &&\
#	grep -Eo '($(FBDVPURL))[^[:space:]"]+' $@_fbdv.tmp | sort | uniq > $@_fbdv_red.tmp &&\
#	cat $@_fbdv_red.tmp $@_prop.tmp | sort | uniq > $@ &&\
#	rm $@_prop.tmp $@_fbdv.tmp $@_fbdv_red.tmp 

#imports/fbdv_import.owl: mirror/fbdv.owl imports/fbdv_terms_combined.txt imports/fbdv_filter_seed.txt
#	@if [ $(IMP) = true ]; then $(ROBOT) extract -i $< -T imports/fbdv_terms_combined.txt --method BOT \
#		filter --term-file imports/fbdv_filter_seed.txt --trim true --select "annotations anonymous parents self" --preserve-structure false \
#		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@; fi
#.PRECIOUS: imports/fbdv_import.owl

###############################################################
########### Manage ORIGINAL DOSDP patterns! ###################
# This is an isolated bit of code that can be deleted once the transition to the new pattern based system is complete.

#original_tsvs := $(patsubst %.yaml, $(PATTERNDIR)/data/original/%.tsv, $(notdir $(wildcard $(PATTERNDIR)/dosdp-patterns/dpo*.yaml)))
#pattern_term_lists_original := $(patsubst %.tsv, $(PATTERNDIR)/data/original/%.txt, $(notdir $(wildcard $(PATTERNDIR)/data/original/*.tsv)))
#individual_patterns_original := $(patsubst %.tsv, $(PATTERNDIR)/data/original/%.ofn, $(notdir $(wildcard $(PATTERNDIR)/data/original/*.tsv)))

#$(PATTERNDIR)/data/original/%.txt: $(PATTERNDIR)/dosdp-patterns/%.yaml $(PATTERNDIR)/data/original/%.tsv .FORCE
#	dosdp-tools terms --infile=$(word 2, $^) --template=$< --obo-prefixes=true --outfile=$@

#$(PATTERNDIR)/data/original/%.tsv:
#	dosdp-tools query --ontology=$(SRC) --reasoner=elk --template=../patterns/dosdp-patterns/$*.yaml --obo-prefixes=true --outfile=$@

#$(PATTERNDIR)/data/original/%.ofn: $(PATTERNDIR)/data/original/%.tsv $(PATTERNDIR)/dosdp-patterns/%.yaml $(SRC)
#	dosdp-tools generate --catalog=catalog-v001.xml --infile=$< --template=$(word 2, $^) --ontology=$(word 3, $^) --obo-prefixes=true --restrict-axioms-to=logical --outfile=$@

#$(PATTERNDIR)/definitions_original.owl: $(individual_patterns_original)
#	$(ROBOT) merge $(addprefix -i , $(individual_patterns_original)) \
#	annotate --ontology-iri $(ONTBASE)/patterns/definitions_original.owl  --version-iri $(ONTBASE)/releases/$(TODAY)/patterns/definitions.owl -o definitions.ofn &&\
#	mv definitions.ofn $@

#prepare_patterns_orig:	
#	touch $(pattern_term_lists_original) &&\
#	touch $(individual_patterns_original)

#$(PATTERNDIR)/data/to_do/%.ofn: $(PATTERNDIR)/data/to_do/%.tsv $(PATTERNDIR)/dosdp-patterns/%.yaml $(SRC)
#	dosdp-tools generate --catalog=catalog-v001.xml --infile=$< --template=$(word 2, $^) --ontology=$(word 3, $^) --obo-prefixes=true --outfile=$@

#test_xref_pattern: $(PATTERNDIR)/data/to_do/dpoAbnormalEntityTestXref.ofn

#original_patterns: $(PATTERNDIR)/definitions_original.owl

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
### Overwriting some default aretfacts ###
######################################################

# Simple is overwritten to strip out duplicate names and definitions.
$(ONT)-simple.obo: $(ONT)-simple.owl
	$(ROBOT) convert --input $< --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
	sed -i '/subset[:] ro[-]eco/d' $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

# We want the OBO release to be based on the simple release. It needs to be annotated however in the way map releases (fbbt.owl) are annotated.
$(ONT).obo: $(ONT)-simple.owl
	$(ROBOT)  annotate --input $< --ontology-iri $(URIBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY) \
	convert --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
	sed -i '/subset[:] ro[-]eco/d' $@.tmp &&\
	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\ndef[:]/def:/g; print' > $@
	rm -f $@.tmp.obo $@.tmp

############################################################
### Code for generating class hierarchy for lethal terms ###
############################################################

tmp/lethal_terms.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-lethal.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

#tmp/lethal_terms_tsv.txt: $(SRC)
#	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-lethal-tsv.sparql $@.tmp
#	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp	
# $(ROBOT) remove --input $< --select imports \

#tmp/lethal_module.owl: $(SRC) tmp/lethal_terms.txt
#	$(ROBOT) extract --input $< -T tmp/lethal_terms.txt --force true --imports exclude --method STAR \
#		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@;

components/lethal_class_hierarchy.owl: $(SRC) tmp/lethal_terms.txt
	rm $@ && touch $@
	$(ROBOT) merge --input $< \
		convert --output tmp/edit.owx
	Konclude classification -i tmp/edit.owx -o tmp/konclude-edit.owx
	$(ROBOT) filter -i tmp/konclude-edit.owx -T tmp/lethal_terms.txt --trim false \
	annotate --ontology-iri $(ONTBASE)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@

######################################################
### Code for generating additional FlyBase reports ###
######################################################

REPORT_FILES := $(REPORT_FILES) reports/obo_track_new_simple.txt reports/onto_metrics_calc.txt reports/robot_simple_diff.txt reports/chado_load_check_simple.txt

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
	../scripts/chado_load_checks.pl $(ONT)-simple.obo > $@

all_reports: all_reports_onestep $(REPORT_FILES)

prepare_release: $(ASSETS) $(PATTERN_RELEASE_FILES)
	rsync -R $(ASSETS) $(RELEASEDIR) &&\
  mkdir -p $(RELEASEDIR)/patterns &&\
  cp $(PATTERN_RELEASE_FILES) $(RELEASEDIR)/patterns &&\
  echo "Release files are now in $(RELEASEDIR) - now you should commit, push and make a release on github"
	
# Simple is overwritten to strip out duplicate names and definitions.

#simple_obo:
#	$(ROBOT) convert --input dpo-simple.owl --check false -f obo $(OBO_FORMAT_OPTIONS) -o $@.tmp.obo &&\
#	grep -v ^owl-axioms $@.tmp.obo > $@.tmp &&\
#	cat $@.tmp | perl -0777 -e '$$_ = <>; s/name[:].*\nname[:]/name:/g; print' | perl -0777 -e '$$_ = <>; s/def[:].*\nname[:]/def:/g; print' > dpo-simple.obo

#####################################################################################
### Regenerate placeholder definitions                                            ###
#####################################################################################
# There are two types of definitions that FBCV uses: "." (DOT-) definitions are those for which the formal 
# definition is translated into a human readable definitions. "$sub_" (SUB-) definitions are those that have 
# special placeholder string to substitute in definitions from external ontologies, mostly CHEBI

tmp/auto_generated_definitions_seed_dot.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $(SRC) --query ../sparql/dot-definitions.sparql $@.tmp &&\
	cat $@.tmp | sort | uniq >  $@
	rm -f $@.tmp
	
tmp/auto_generated_definitions_seed_sub.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $(SRC) --query ../sparql/classes-with-placeholder-definitions.sparql $@.tmp &&\
	cat $@.tmp | sort | uniq >  $@
	rm -f $@.tmp

mirror/chebi.owl: mirror/chebi.trigger
	@if [ $(MIR) = true ] && [ $(IMP) = true ]; then wget http://ftp.ebi.ac.uk/pub/databases/chebi/ontology/chebi.owl.gz -O mirror/chebi.owl.gz && $(ROBOT) convert -i mirror/chebi.owl.gz -o $@.tmp.owl && mv $@.tmp.owl $@; fi


tmp/merged-source-pre.owl: $(SRC) mirror/chebi.owl
	$(ROBOT) merge -i $(SRC) -i mirror/chebi.owl --output $@

tmp/auto_generated_definitions_dot.owl: tmp/merged-source-pre.owl tmp/auto_generated_definitions_seed_dot.txt
	java -jar ../scripts/eq-writer.jar $< tmp/auto_generated_definitions_seed_dot.txt flybase $@ NA add_dot_refs

tmp/auto_generated_definitions_sub.owl: tmp/merged-source-pre.owl tmp/auto_generated_definitions_seed_sub.txt
	java -jar ../scripts/eq-writer.jar $< tmp/auto_generated_definitions_seed_sub.txt sub_external $@ NA source_xref

pre_release: $(ONT)-edit.owl all_imports tmp/auto_generated_definitions_dot.owl tmp/auto_generated_definitions_sub.owl #components/lethal_class_hierarchy.owl
	cp $(ONT)-edit.owl tmp/$(ONT)-edit-release.owl
	sed -i '/AnnotationAssertion[(]obo[:]IAO[_]0000115.*\"[.]\"/d' tmp/$(ONT)-edit-release.owl
	sed -i '/sub_/d' tmp/$(ONT)-edit-release.owl
	$(ROBOT) merge -i tmp/$(ONT)-edit-release.owl -i tmp/auto_generated_definitions_dot.owl -i tmp/auto_generated_definitions_sub.owl --collapse-import-closure false -o $(ONT)-edit-release.ofn && mv $(ONT)-edit-release.ofn $(ONT)-edit-release.owl
	echo "Preprocessing done. Make sure that NO CHANGES TO THE EDIT FILE ARE COMMITTED!"
	

########################
##    TRAVIS       #####
########################

obo_qc_%:
	$(ROBOT) report -i $* --profile qc-profile.txt --fail-on ERROR --print 5 -o $@.txt

obo_qc: obo_qc_$(ONT).obo obo_qc_$(ONT).owl

# All this removing is necessary to avoid problems with remove --term CARO:0000013 remove --term GO:0005623 
flybase_qc.owl: odkversion obo_qc
	$(ROBOT) merge -i $(ONT)-full.owl -i components/qc_assertions.owl -o $@

flybase_qc: flybase_qc.owl
	$(ROBOT) reason -i $< --reasoner ELK  --equivalent-classes-allowed asserted-only -o test.owl &&\
	rm test.owl && echo "Success"
