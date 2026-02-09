# Development documentation

## Adding new profile workflow

:::note
Does not have to be in this precise order
:::

- [ ] Installed modules `nf-core modules install <tool>/<subtool>`
- [ ] Added parameters to `nextflow.config`
  - [ ] Added `--build_<profiler>`
  - [ ] Added `--<profiler>_build_params`
  - [ ] Added other profiler-specific parameters (e.g. additional taxonomy files)
  - [ ] Format with VSCode Nextflow extension
- [ ] Update the `subworkflows/local/preprocessing/main.nf`
  - [ ] Update the subworkflow's if/else (concatenation) sections for either DNA or AA FASTA preprocessing
  - [ ] Format with VSCode Nextflow extension
- [ ] Added tools(s) to `workflow/createtaxdb.nf`
  - [ ] Added relevant new input files to `take:` block, and pass into from `main.nf` to the `NFCORE_CREATETAXDB` workflow
  - [ ] Added relevant modules/subworkflows at the top using `include` statement
  - [ ] Added the tool-specific if/else statement in the main `createtaxdb.nf`
  - [ ] Version and MultiQC (if available) channels mixed
  - [ ] Include output channel in workflow `emit` statement
  - [ ] Format with VSCode Nextflow extension
- [ ] Update `modules.conf` if additional customisation required
  - [ ] Added `withName:` block
  - [ ] Added `ext.args = ${params.<profiler>_build_params}`
  - [ ] Added other args (`ext.args`) based on additional profiler specific parameters modules
  - [ ] Format with VSCode Nextflow extension
- [ ] If necessary, added any profiler-specific parameter validation checks to `utils_nfcore_createtaxdb_pipeline` and possible at the top of `createtaxdb.nf`
- [ ] Update tests
  - [ ] Include the tool in the `test_minimal.config` (as false), `test.config` and `test_full.config` (as true), and `test_alternatives.config`, as required.
  - [ ] Run a mini test of `test_minimal` to make sure it executes when sole tool
  - [ ] Format these files with VSCode Nextflow extension
  - [ ] Include the output object in the `tests/test.nf.test` file
  - [ ] Re-run nf-test to update snapshot: `nf-test test --tag test --profile +docker --update-snapshot` (tip: for assertions, borrow from the modules assertions!)
- [ ] Update Documentation
  - [ ] `nf-core pipelines schema build` has been run and updated
    - [ ] All additional tool specific pipeline parameters have a additional help entry with the `Modifies tool parameter(s)` quote block
  - [ ] Added citation to `citations.md` (citation style: APA 7th edition)
  - [ ] Add citation to the toolCitation/BibliographyText functions in `utils_nfcore_createtaxdb_pipeline` subworkflow
    - [ ] Added in-text citation
    - [ ] Added bibliography (citation style: APA 7th edition)
  - [ ] Added relevant documentation to `usage.md`
    - [ ] Add line to FAQ of recommended auxiliary files (if required)
  - [ ] Described module output in `output.md`
    - [ ] Entry in table of contents
    - [ ] Entry describing output file and how to supply it to the downstream classification tool
  - [ ] Added to pipeline summary list on `README.md`
  - [ ] Added to pipeline metro map diagram
  - [ ] If it's your first contribution, add or move yourself to the Team list on `README.md`!
- [ ] Test(s) pass
