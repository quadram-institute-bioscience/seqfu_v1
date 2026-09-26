---
layout: home
title: Home
nav_order: 1
---

<a href="https://quadram-institute-bioscience.github.io/seqfu_v1" description="SeqFu documentation">
  <img align="right" width="128" height="128" src="img/seqfu-512.png">
</a>

# SeqFu

[![GitHub Stars](https://img.shields.io/github/stars/quadram-institute-bioscience/seqfu_v1?label=⭐️)](https://github.com/quadram-institute-bioscience/seqfu_v1)
[![Latest release](https://img.shields.io/github/v/release/quadram-institute-bioscience/seqfu_v1)](https://github.com/quadram-institute-bioscience/seqfu_v1/releases)
[![Bioconda Downloads](https://img.shields.io/conda/dn/bioconda/seqfu?label=Bioconda%20Downloads)](https://anaconda.org/bioconda/seqfu)

📦 See the **[repository](https://github.com/quadram-institute-bioscience/seqfu_v1)** | 💾 **[releases](https://github.com/quadram-institute-bioscience/seqfu_v1/releases)**

> **Note:** This repository maintains the **1.x stable branch** of SeqFu.
> Active development of SeqFu 2.0 continues in the original repository at
> [telatin/seqfu2](https://github.com/telatin/seqfu2).
> This fork is maintained by the [Quadram Institute Bioscience](https://www.quadram.ac.uk)
> to provide long-term support for the 1.x series.

A general-purpose program to manipulate and parse information from FASTA/FASTQ files,
supporting gzipped input files.
Includes functions to _interleave_ and _de-interleave_ FASTQ files,
to _rename_ sequences and to _count_ and print _statistics_ on sequence lengths.
SeqFu is available for Linux and MacOS.

* A compiled program delivering high performance analyses
* Supports FASTA/FASTQ files, also Gzip compressed
* A growing collection of handy utilities, also for quick inspection of the datasets
* UNIX like commands but specific for sequences like `seqfu cat`, `seqfu head`, `seqfu tail`, `seqfu grep`
* Terminal friendly reports from `seqfu stats` or `seqfu count`...

Can be easily [installed](installation) via conda:

```bash
conda install -c conda-forge -c bioconda "seqfu>=1.0,<2.0"
```

## Citation

Telatin A, Fariselli P, Birolo G. _SeqFu: A Suite of Utilities for the Robust
and Reproducible Manipulation of Sequence Files_.
Bioengineering 2021, 8, 59. [doi.org/10.3390/bioengineering8050059](https://doi.org/10.3390/bioengineering8050059)
