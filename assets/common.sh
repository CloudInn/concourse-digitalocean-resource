#!/usr/bin/env bash

set -eu

payload=$(cat) # reading input from stdin (source/params/etc..)

# a random version to always return to concourse to guarantee it will always execute get (and destroy worker) instead of using cache and does nothing
random_ver=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 15 | head -n 1)

# if
check_create(){
  dont_get=$(echo "$payload" | jq -r '.params.dont_get // false')
}

# initializing variables
init_vars(){
  GENERATED_WORKER_NAME=$(echo "ci-worker-$BUILD_PIPELINE_NAME-$BUILD_JOB_NAME" | sed -r 's/[^a-zA-Z0-9]+/-/g')
  READ_WORKER_NAME=$(echo "$payload" | jq -r '.params.worker_name // ""')
  WORKER_NAME=${READ_WORKER_NAME}
  DO_API_KEY=$(echo "$payload" | jq -er '.source.api_key // ""')
  DO_REGION=$(echo "$payload" | jq -r '.source.region // "ams3"')
  DO_SIZE=$(echo "$payload" | jq -r '.source.droplet_size // "s-2vcpu-2gb"')
  DO_DROPLET_KEY=$(echo "$payload" | jq -er '.source.droplet_key // ""')
  CO_WEB_HOST="$ATC_EXTERNAL_URL"
  CO_WORKER_KEY=$(echo "$payload" | jq -er '.source.ci_worker_key // ""')
  CO_TSA_PUB_KEY=$(echo "$payload" | jq -er '.source.ci_tsa_pub_key // ""')
  CO_TSA_PORT=$(echo "$payload" | jq -er '.source.ci_tsa_port // "2222"')
  CO_TSA_HOST=$(echo "$ATC_EXTERNAL_URL" | pcregrep -o1 "^(?:https?:)?(?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:\/\n]+)"):"$CO_TSA_PORT"
  FLY_USERNAME=$(echo "$payload" | jq -er '.source.fly_username // ""')
  FLY_PASSWORD=$(echo "$payload" | jq -er '.source.fly_password // ""')

  keys=$(mktemp -d /var/tmp/do-resource.XXXXXX)
  echo "$CO_WORKER_KEY" > $keys/worker_key
  echo "$CO_TSA_PUB_KEY" > $keys/tsa_host_key.pub
  echo "$DO_DROPLET_KEY" > $keys/id_rsa
}

init_fly(){
  # download and configure fly client
  if [ -z "$(which fly)" ]; then
    curl "$CO_WEB_HOST/api/v1/cli?arch=amd64&platform=linux" -sSLo /usr/bin/fly
    chmod +x /usr/bin/fly
  fi
  fly -t main l -u$FLY_USERNAME -p$FLY_PASSWORD -c $CO_WEB_HOST > /dev/null
}

get_concourse_version(){
  # get concourse version
  CO_VERSION=$(fly -t main sync | cut -d' ' -f2)
}

init_ssh(){
# configure ssh-agent to use the digitalocean private key and bypass hostkey verification
chmod 0600 $keys/id_rsa
mkdir -p ~/.ssh
cp $keys/id_rsa ~/.ssh/
cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
chmod 0600 ~/.ssh/config
}
