#!/usr/bin/env bash

# arguments
#########################################################################################
input_bam=$1
ref_version=$2
contig_style=$3
output_folder=$4

# variables
#########################################################################################
spark=/usr/bin/spark-submit
#time=`date +"%s"`
time=$output_folder
alignment_parquet=hdfs:///${time}-alignment.parquet
alignment_bam=hdfs:///${time}-alignment.bam
make_example_dir=hdfs:///${time}-dv-I
call_variants_dir=hdfs:///${time}-dv-II
postprocess_variants_dir=hdfs:///${time}-dv-III
bed_path=hdfs:///bed/${ref_version}/contiguous_unmasked_regions_156_parts

# functions
#########################################################################################
usage() {
  echo "Usage:"
  echo $'\t' "$0 <Input BAM> <Output Folder> <Reference Version> <Contig Style>"
  echo "Parameters:"
  echo $'\t' "<Input BAM>: the input bam file from Google Strorage or HDFS"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo "Examples: "
  echo $'\t' "./run.sh gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam output 19 GRCH"
  return
}

print_time () {
  diff=$(($3 - $2))
  str_diff=`date +%H:%M:%S -ud @${diff}`
  echo $1 $'\t' $str_diff
}

# argument check
#########################################################################################
if [[ $# -ne 4 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 4, Actual: $#)"
  usage $0
  exit -1
fi

if [[ ${ref_version} != "19" && ${ref_version} != "38" ]]; then
  echo "[ERROR]: unsupported ref version - ${ref_version}"
  usage $0
  exit -2
fi

if [[ ${contig_style} != "HG" && ${contig_style} != "GRCH" ]]; then
  echo "[ERROR]: unsupported contig style -- ${contig_style}"
  usage $0
  exit -3
fi

# main
##########################################################################################
# adam
${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name AtgxTransform \
  --class org.bdgenomics.adam.cli.ADAMMain \
  --num-executors 10  \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 35g \
  --executor-cores 4 \
  --queue default \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator \
  /usr/local/seqslab/adam/adam-assembly/target/adam.jar transformAlignments \
      ${input_bam} \
      ${alignment_parquet} \
      -force_load_bam -atgx_transform -parquet_compression_codec SNAPPY

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "adam transform failed"
    echo
    echo "###########################################################"
    exit -1
fi