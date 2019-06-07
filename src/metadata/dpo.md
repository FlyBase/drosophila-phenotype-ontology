---
layout: ontology_detail
id: dpo
title: Drosophila Phenotype Ontology
jobs:
  - id: https://travis-ci.org/FlyBase/drosophila-phenotype-ontology
    type: travis-ci
build:
  checkout: git clone https://github.com/FlyBase/drosophila-phenotype-ontology.git
  system: git
  path: "."
contact:
  email: 
  label: 
  github: 
description: Drosophila Phenotype Ontology is an ontology...
domain: stuff
homepage: https://github.com/FlyBase/drosophila-phenotype-ontology
products:
  - id: dpo.owl
    name: "Drosophila Phenotype Ontology main release in OWL format"
  - id: dpo.obo
    name: "Drosophila Phenotype Ontology additional release in OBO format"
  - id: dpo.json
    name: "Drosophila Phenotype Ontology additional release in OBOJSon format"
  - id: dpo/dpo-base.owl
    name: "Drosophila Phenotype Ontology main release in OWL format"
  - id: dpo/dpo-base.obo
    name: "Drosophila Phenotype Ontology additional release in OBO format"
  - id: dpo/dpo-base.json
    name: "Drosophila Phenotype Ontology additional release in OBOJSon format"
dependencies:
- id: fbdv
- id: fbbt
- id: go
- id: ro
- id: chebi
- id: pato

tracker: https://github.com/FlyBase/drosophila-phenotype-ontology/issues
license:
  url: http://creativecommons.org/licenses/by/3.0/
  label: CC-BY
activity_status: active
---

Enter a detailed description of your ontology here. You can use arbitrary markdown and HTML.
You can also embed images too.

