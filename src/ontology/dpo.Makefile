## Customize Makefile settings for dpo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile
FBDVPURL=http://purl.obolibrary.org/obo/FBdv_

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

tmp/all_patternised_classes.txt:
	$(ROBOT) query --use-graphs false -f csv -i $(PATTERNDIR)/definitions_original.owl --query ../sparql/dpo-equivalent-classes.sparql $@.tmp
	cat $@.tmp | sort | uniq >  $@ && rm -f $@.tmp

tmp/remaining_classes.txt: tmp/all_patternised_classes.txt tmp/all_defined_classes.txt
	comm -13 $^ > $@

tmp/remaining_definitions.owl: $(SRC) tmp/remaining_classes.txt
	$(ROBOT) filter -i $< -T tmp/remaining_classes.txt --axioms "equivalent annotation" --trim false -o $@

