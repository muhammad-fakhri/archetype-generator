#!/bin/bash
# init.sh
# repo generator
# Usage     : sourced

# Prerequisites :
# config yaml file

path=$(dirname $0)
temp_dir=temp
generator_dir=${temp_dir}/generator
template_dir=${temp_dir}/template

tf=transformations.yaml

source $path/utils.sh

# template generator
function generate_be() {

   enabled="yes"
   use_redis=${service_redis}
   use_db_sql=${service_db_sql}
   use_db_mongo=${service_db_mongo}
   use_gcs=${service_gcs}
   use_email=${service_email}
   use_pubsub=${service_pubsub}
   use_example=${service_example}
   use_example_cron=${service_example_cron}

   if [[ $use_example == $enabled ]]; then
      echo "Using example, automatically include all components ..."
      use_redis=$enabled
      use_db_sql=$enabled
      use_db_mongo=$enabled
      use_gcs=$enabled
      use_email=$enabled
      use_pubsub=$enabled
   fi

   if [ ! -d "$template_dir" ] 
   then
      echo "Initializing a ${project_name} repository ..."
      if ! git clone --branch ${config_src} https://github.com/muhammad-fakhri/archetype-be $template_dir; then
         print_error "Not authorized to clone repo. Please ask for permission."
         exit 1
      fi
   fi

   if [ ! -d "$generator_dir" ] 
   then
      echo "Download archetype generator"
      mkdir -p $generator_dir && cd $generator_dir && curl -sL https://github.com/rantav/go-archetype/releases/download/v0.1.11/go-archetype_0.1.11_${config_env}_x86_64.tar.gz | tar xz
      cd ../../
   fi

   print_green "Creating project ${project_name} with repo ${project_repo_path}"
   if [ -d "${project_name}" ] 
   then
      print_yellow "Output path $project_name already exist, overwrite? (y/n)"
      read -r
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
         rm -rf ${project_name}
      else
         print_red "Aborting template generator"
         exit 1
      fi
   fi

   LOG_LEVEL=info $generator_dir/go-archetype transform --transformations $tf \
      --source=$template_dir \
      --destination=${project_name} \
      -- \
      --project_name ${project_name} \
      --project_team ${project_team} \
      --project_repo_path ${project_repo_path} \
      --include_redis $use_redis \
      --include_db_sql $use_db_sql \
      --include_db_mongo $use_db_mongo \
      --include_pubsub $use_pubsub \
      --include_email $use_email \
      --include_gcs $use_gcs \
      --include_example $use_example \
      --include_example_cron $use_example_cron

   rm -rf ${temp_dir}
   
   if [ ! -d "$project_name" ] 
   then
      print_red "Failed to generate project ${project_name}"
   else
      cd $project_name
      go test ./...
   fi
}

# entry point
eval $(parse_yaml_file parameters.yaml "" "_")
setup_mode=$(echo ${project_type} | tr -d '[:space:]')
case ${setup_mode} in
  be) generate_be;;
  *)  print_error "invalid configuration!";
   exit 1;;
esac
