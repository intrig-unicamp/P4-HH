# DIR is this file directory.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "${DIR}/" && pwd )"

output_dir="${ROOT_DIR}"
     echo "*** Output in ${output_dir}"

BFSDE_P4C_COMPILER_IMG=BFSDE_P4C:latest
PIPELINE_CONFIG_BUILDER_IMG=stratumproject/stratum-bf-pipeline-builder:latest

# compile the P4 code and outputs will be in the 'output_dir' directory
docker run --rm -v "${output_dir}:${output_dir}" -w "${output_dir}" BFSDE_P4C_COMPILER_IMG \
     bf-p4c --arch tna -g --create-graphs \
     --verbose 2 -o output_dir --p4runtime-files output_dir/p4info.txt \
     --p4runtime-force-std-externs IPG-HH.p4 \
     $@

# generate the pipeline_config.pb.bin for p4runtime shell
docker run --rm -v "${output_dir}/output_dir:${output_dir}/output_dir" -w "${output_dir}/output_dir" \
     ${PIPELINE_CONFIG_BUILDER_IMG} \
     -p4c_conf_file=./IPG-HH.conf \
     -bf_pipeline_config_binary_file=./pipeline_config.pb.bin
