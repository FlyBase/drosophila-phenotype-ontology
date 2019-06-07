---
layout: ontology_detail
id: dpo
title: FlyBase Controlled Vocabulary
jobs:
  - id: https://travis-ci.org/FlyBase/flybase-controlled-vocabulary
    type: travis-ci
build:
  checkout: git clone https://github.com/FlyBase/flybase-controlled-vocabulary.git
  system: git
  path: "."
contact:
  email: 
  label: 
  github: 
description: FlyBase Controlled Vocabulary is an ontology...
domain: stuff
homepage: https://github.com/FlyBase/flybase-controlled-vocabulary
products:
  - id: dpo.owl
    name: "FlyBase Controlled Vocabulary main release in OWL format"
  - id: dpo.obo
    name: "FlyBase Controlled Vocabulary additional release in OBO format"
  - id: dpo.json
    name: "FlyBase Controlled Vocabulary additional release in OBOJSon format"
  - id: dpo/dpo-base.owl
    name: "FlyBase Controlled Vocabulary main release in OWL format"
  - id: dpo/dpo-base.obo
    name: "FlyBase Controlled Vocabulary additional release in OBO format"
  - id: dpo/dpo-base.json
    name: "FlyBase Controlled Vocabulary additional release in OBOJSon format"
dependencies:
- id: fbdv
- id: fbbt
- id: go
- id: ro
- id: chebi
- id: pato

tracker: https://github.com/FlyBase/flybase-controlled-vocabulary/issues
license:
  url: http://creativecommons.org/licenses/by/3.0/
  label: CC-BY
activity_status: active
---

Enter a detailed description of your ontology here. You can use arbitrary markdown and HTML.
You can also embed images too.

