
def make_contig_groups()

rule make_metabat2_depth_file:
    """
    Uses jgi_summarize_bam_contig_depths to generate a depth.txt file.
    """
    input:
        #bams=rules.sort_bam_bt2.output.bam
        bams = lambda wildcards: expand("output/binning/{mapper}/mapped_reads/{read_sample}.MappedTo.{contig_sample}.sorted.bam",
                        mapper=wildcards.mapper,
                        contig_sample=wildcards.contig_sample,
                        read_sample=contig_pairings[wildcards.contig_sample])
    output:
        coverage_table="output/binning/metabat2/{contig_sample}_coverage_table.txt"
    conda:
        "../env/binning.yaml"
    benchmark:
        "output/benchmarks/metabat2/make_metabat2_depth_file/{contig_sample}_benchmark.txt"
    log:
        "output/logs/metabat2/make_metabat2_depth_file/{contig_sample}.log"
    shell:
        """
            jgi_summarize_bam_contig_depths --outputDepth {output.coverage_table} {input.bams}
        """

rule run_metabat2:
    """
    Runs metabat2
    """
    input:
        contigs = lambda wildcards: get_contigs(wildcards.contig_sample,
                                                binning_df),
        depth=rules.make_metabat2_depth_file.output.depth
    output:
        bins="output/binning/metabat2/bins/{contig_sample}_bins",
    conda:
        "../env/binning.yaml"
    threads:
        config['threads']['metabat2']
    benchmark:
        "output/benchmarks/metabat2/run_metabat2/{contig_sample}_benchmark.txt"
    log:
        "output/logs/metabat2/run_metabat2/{contig_sample}.log"
    shell:
        """
            metabat2 \
            -i {input.contigs} \
            -o {output.bins} \
            -a {input.depth} \
            -t {threads} -v
        """


rule cut_up_fasta:
    """

    Cut up fasta file in non-overlapping or overlapping parts of equal length.
    Optionally creates a BED-file where the cutup contigs are specified in terms
    of the original contigs. This can be used as input to concoct_coverage_table.py.

    """
    input:
        contigs="output/assemble/metaspades/{contig_sample}.contigs.fasta"
    output:
        bed="output/binning/{contig_sample}_contigs_10K.bed",
        contigs_10K="output/binning/{contig_sample}_contigs_10K.fa"

    conda:
        "../env/binning.yaml"
    params:
        chunk_size=config['params']['concoct']['chunk_size'],
        overlap_size=config['params']['concoct']['overlap_size']
    benchmark:
        "output/benchmarks/concoct/cut_up_fasta/{contig_sample}_benchmark.txt"
    log:
        "output/logs/concoct/cut_up_fasta/{contig_sample}.log"
    shell:
        """
          python resources/scripts/cut_up_fasta.py {input.contigs} \
          -c {params.chunk_size} \
          -o {params.overlap_size} \
          --merge_last \
          -b {output.bed} > {output.contigs_10K}
        """


rule make_concoct_coverage_table:
    """

    Generates table with per sample coverage depth.
    Assumes the directory "/output/binning/bowtie2/mapped_reads/" contains sorted bam files where each read file has been bt2 mapped against contigs from the selected samples.

    """
    input:
        bed=expand("output/binning/{contig_sample}_contigs_10K.bed", contig_sample=contig_samples),
        bams = lambda wildcards: expand("output/binning/{mapper}/sorted_reads/{read_sample}.MappedTo.{contig_sample}.sorted.bam",
                        mapper=config['mappers'],
                        contig_sample=wildcards.contig_sample,
                        read_sample=read_samples)

    output:
#        temp_dir=directory("output/binning/{read_sample}_temp"),
        coverage_table="output/binning/concoct/{read_sample}_coverage_table.txt"
    conda:
        "../env/binning.yaml"
    benchmark:
        "output/benchmarks/concoct/concoct_coverage_table/{read_sample}_benchmark.txt"
    log:
        "output/logs/concoct/concoct_coverage_table/{read_sample}.log"
    shell:
        """
          python resources/scripts/concoct_coverage_table.py {input.bed} \
          {input.bams} > {output.coverage_table}
        """


rule make_maxbin2_coverage_table:
    """
      Commands to generate a coverage table using `samtools coverage` for input into maxbin2
    """
    input:
        bams = lambda wildcards: expand("output/binning/{mapper}/sorted_reads/{read_sample}.MappedTo.{contig_sample}.sorted.bam",
                        mapper=config['mappers'],
                        contig_sample=wildcards.contig_sample,
                        read_sample=read_samples)

    output:
        coverage_table="output/binning/maxbin2/{read_sample}_coverage_table.txt"
    conda:
        "../env/binning.yaml"
    benchmark:
        "output/benchmarks/maxbin2/maxbin2_coverage_table/{read_sample}_benchmark.txt"
    log:
        "output/logs/maxbin2/maxbin2_coverage_table/{read_sample}.log"
    shell:
        """
          samtools view -h {input.bams} | \
          samtools coverage | \
          tail -n +2 | \
          sort -k1 | \
          cut -f1,6 > {output.coverage_table}
        """
