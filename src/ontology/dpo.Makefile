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
