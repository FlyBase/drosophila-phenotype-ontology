## Customize Makefile settings for dpo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile
FBDVPURL=http://purl.obolibrary.org/obo/FBdv_
#OTHER_SRC:= $(OTHER_SRC) components/lethal_class_hierarchy.owl

imports/fbdv_filter_seed.txt: $(SRC) #$(ONTOLOGYTERMS) #prepare_patterns
	$(ROBOT) query --use-graphs true -f csv -i $< --query ../sparql/object-properties.sparql $@_prop.tmp &&\
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/terms.sparql $@_fbdv.tmp &&\
	grep -Eo '($(FBDVPURL))[^[:space:]"]+' $@_fbdv.tmp | sort | uniq > $@_fbdv_red.tmp &&\
	cat $@_fbdv_red.tmp $@_prop.tmp | sort | uniq > $@ &&\
	rm $@_prop.tmp $@_fbdv.tmp $@_fbdv_red.tmp 

imports/fbdv_import.owl: mirror/fbdv.owl imports/fbdv_terms_combined.txt imports/fbdv_filter_seed.txt
	@if [ $(IMP) = true ]; then $(ROBOT) extract -i $< -T imports/fbdv_terms_combined.txt --method BOT \
		filter --term-file imports/fbdv_filter_seed.txt --trim true --select "annotations anonymous parents self" --preserve-structure false \
		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@; fi
.PRECIOUS: imports/fbdv_import.owl

components/lethal_class_hierarchy.owl: $(SRC) tmp/lethal_terms.txt
	$(ROBOT) merge --input $< \
		convert --output tmp/edit.owx
	Konclude classification -i tmp/edit.owx -o tmp/konclude-edit.owx
	$(ROBOT) filter -i tmp/konclude-edit.owx -T tmp/lethal_terms.txt --trim false \
	annotate --ontology-iri $(ONTBASE)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@

###############################################################
########### Manage ORIGINAL DOSDP patterns! ###################
# This is an isolated bit of code that can be deleted once the transition to the new pattern based system is complete.

original_tsvs := $(patsubst %.yaml, $(PATTERNDIR)/data/original/%.tsv, $(notdir $(wildcard $(PATTERNDIR)/dosdp-patterns/dpo*.yaml)))
pattern_term_lists_original := $(patsubst %.tsv, $(PATTERNDIR)/data/original/%.txt, $(notdir $(wildcard $(PATTERNDIR)/data/original/*.tsv)))
individual_patterns_original := $(patsubst %.tsv, $(PATTERNDIR)/data/original/%.ofn, $(notdir $(wildcard $(PATTERNDIR)/data/original/*.tsv)))

$(PATTERNDIR)/data/original/%.txt: $(PATTERNDIR)/dosdp-patterns/%.yaml $(PATTERNDIR)/data/original/%.tsv .FORCE
	dosdp-tools terms --infile=$(word 2, $^) --template=$< --obo-prefixes=true --outfile=$@

$(PATTERNDIR)/data/original/%.tsv:
	dosdp-tools query --ontology=$(SRC) --reasoner=elk --template=../patterns/dosdp-patterns/$*.yaml --obo-prefixes=true --outfile=$@

$(PATTERNDIR)/data/original/%.ofn: $(PATTERNDIR)/data/original/%.tsv $(PATTERNDIR)/dosdp-patterns/%.yaml $(SRC)
	dosdp-tools generate --catalog=catalog-v001.xml --infile=$< --template=$(word 2, $^) --ontology=$(word 3, $^) --obo-prefixes=true --restrict-axioms-to=logical --outfile=$@

$(PATTERNDIR)/definitions_original.owl: $(individual_patterns_original)
	$(ROBOT) merge $(addprefix -i , $(individual_patterns_original)) \
	annotate --ontology-iri $(ONTBASE)/patterns/definitions_original.owl  --version-iri $(ONTBASE)/releases/$(TODAY)/patterns/definitions.owl -o definitions.ofn &&\
	mv definitions.ofn $@

prepare_patterns_orig:	
	touch $(pattern_term_lists_original) &&\
	touch $(individual_patterns_original)

original_patterns: $(PATTERNDIR)/definitions_original.owl

tmp/all_defined_classes.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-equivalent-classes.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp
	
tmp/lethal_terms.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-lethal.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp
	
tmp/lethal_terms_tsv.txt: $(SRC)
	$(ROBOT) query --use-graphs false -f csv -i $< --query ../sparql/dpo-lethal-tsv.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp
	
# $(ROBOT) remove --input $< --select imports \

tmp/lethal_module.owl: $(SRC) tmp/lethal_terms.txt
	$(ROBOT) extract --input $< -T tmp/lethal_terms.txt --force true --imports exclude --method STAR \
		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@;

tmp/all_patternised_classes.txt:
	$(ROBOT) query --use-graphs false -f csv -i $(PATTERNDIR)/definitions_original.owl --query ../sparql/dpo-equivalent-classes.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

tmp/remaining_classes.txt: tmp/all_patternised_classes.txt tmp/all_defined_classes.txt
	comm -13 $^ > $@

tmp/remaining_definitions.owl: $(SRC) tmp/remaining_classes.txt
	$(ROBOT) filter -i $< -T tmp/remaining_classes.txt --axioms "equivalent annotation" --trim false -o $@

$(ONT)-full-hermit.owl: $(SRC)
	$(ROBOT) merge --input $< \
		reason --reasoner hermit \
		relax \
		reduce -r ELK \
		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@

$(ONT)-full-elk.owl: $(SRC)
	$(ROBOT) merge --input $< \
		reason --reasoner elk \
		relax \
		reduce -r ELK \
		annotate --ontology-iri $(ONTBASE)/$@ --version-iri $(ONTBASE)/releases/$(TODAY)/$@ --output $@.tmp.owl && mv $@.tmp.owl $@

tmp/hermitvelk.txt: $(ONT)-full-elk.owl $(ONT)-full-hermit.owl
	$(ROBOT) diff --left $(ONT)-full-elk.owl --right $(ONT)-full-hermit.owl --output $@

######################################################
### Code for generating additional FlyBase reports ###
######################################################

REPORT_FILES := $(REPORT_FILES) reports/obo_track_new_simple.txt reports/onto_metrics_calc.txt reports/chado_load_check_simple.txt

SIMPLE_PURL =	http://purl.obolibrary.org/obo/fbcv/dpo-simple.obo
LAST_DEPLOYED_SIMPLE=tmp/$(ONT)-simple-last.obo

$(LAST_DEPLOYED_SIMPLE):
	wget -O $@ $(SIMPLE_PURL)

flybase_script_base=https://raw.githubusercontent.com/FlyBase/drosophila-anatomy-developmental-ontology/master/tools/release_and_checking_scripts/releases/
onto_metrics_calc=$(flybase_script_base)onto_metrics_calc.pl
chado_load_checks=$(flybase_script_base)chado_load_checks.pl
obo_track_new=$(flybase_script_base)obo_track_new.pl

install_flybase_scripts:
	cp ../scripts/OboModel.pm /usr/local/lib/perl5/site_perl
	wget -O ../scripts/onto_metrics_calc.pl $(onto_metrics_calc) && chmod +x ../scripts/onto_metrics_calc.pl
	wget -O ../scripts/chado_load_checks.pl $(chado_load_checks) && chmod +x ../scripts/chado_load_checks.pl
	wget -O ../scripts/obo_track_new.pl $(obo_track_new) && chmod +x ../scripts/obo_track_new.pl

reports/obo_track_new_simple.txt: $(LAST_DEPLOYED_SIMPLE) install_flybase_scripts $(ONT)-simple.obo
	echo "Comparing with: "$(SIMPLE_PURL) && ../scripts/obo_track_new.pl $(LAST_DEPLOYED_SIMPLE) $(ONT)-simple.obo > $@
	
reports/onto_metrics_calc.txt: $(ONT)-simple.obo install_flybase_scripts
	../scripts/onto_metrics_calc.pl 'phenotypic_class' $(ONT)-simple.obo > $@
	
reports/chado_load_check_simple.txt: $(ONT)-simple.obo install_flybase_scripts
	../scripts/chado_load_checks.pl $(ONT)-simple.obo > $@

all_reports: all_reports_onestep $(REPORT_FILES)