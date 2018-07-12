#!/usr/bin/env bash

# WORKER_NAME  XXX default to "worker-<pipeline>-<job>-<build number>" (substituting anything other alphanumeric with hyphen -)
# DO_API_KEY  XXX source
# DO_SIZE  XXX source (default "s-2vcpu-2gb")
# DO_REGION  XXX source

# DO_VM_KEY  XXX source, check if it's public key fingerprint is add to DO keys or add the public key
# DO_VM_SEED_KEYS_FP  XXX the fingerprint of the previous key ^ (generate it)

# CO_WORKER_KEY  XXX source (this key should be previously added to CONCOURSE_TSA_AUTHORIZED_KEYS)
# CO_TSA_PUB_KEY  XXX source (the public key for CONCOURSE_TSA_HOST_KEY)
# CO_TSA_HOST  XXX extract from (CO_WEB_HOST) adding the default port 2222 or optinal one if set, it's used by worker to connect to tsa
# CO_TSA_PORT  XXX source (to use instead of the default 2222 on previous var ^)
# CO_WEB_HOST  XXX read from the env
# FLY_USERNAME  XXX source
# FLY_PASSWORD  XXX source
# CO_VERSION  XXX get from $(fly sync) command

set -eu

payload=$(cat) # reading input from stdin (source/params/etc..)

# initializing variables
init_vars(){
  WORKER_NAME=$(echo "ci-worker-$BUILD_PIPELINE_NAME-$BUILD_JOB_NAME-$BUILD_NAME" | sed -r 's/[^a-zA-Z0-9]+/-/g')
  DO_API_KEY=$(echo "$payload" | jq -r '.source.api_key // ""')
  DO_REGION=$(echo "$payload" | jq -r '.source.region // ""')
  DO_SIZE=$(echo "$payload" | jq -r '.source.droplet_size // "s-2vcpu-2gb"')
  CO_WEB_HOST="$ATC_EXTERNAL_URL"
  CO_WORKER_KEY=$(echo "$payload" | jq -r '.source.ci_worker_key // ""')
  CO_TSA_PUB_KEY=$(echo "$payload" | jq -r '.source.ci_tsa_pub_key // ""')
  CO_TSA_PORT=$(echo "$payload" | jq -r '.source.ci_tsa_port // "2222"')
  CO_TSA_HOST=$(echo "$ATC_EXTERNAL_URL" | pcregrep -o1 "^(?:https?:)?(?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:\/\n]+)"):"$CO_TSA_PORT"
  FLY_USERNAME=$(echo "$payload" | jq -r '.source.fly_username // ""')
  FLY_USERNAME=$(echo "$payload" | jq -r '.source.fly_password // ""')
}

init_fly(){
  # download and configure fly client
  if [ -z "$(which fly)" ]; then
    curl "$CO_WEB_HOST/api/v1/cli?arch=amd64&platform=linux" -sSLo /usr/bin/fly
    chmod +x /usr/bin/fly
  fi
  fly -t main l -u$FLY_USERNAME -p$FLY_PASSWORD -c $CO_WEB_HOST
}

keys=$(mktemp $TMPDIR/wp-resource-data.XXXXXX)
echo "$CO_WORKER_KEY" > $keys/worker_key
echo "$CO_TSA_PUB_KEY" > $keys/tsa_host_key.pub
echo "$DO_VM_KEY" > $keys/id_rsa

get_concourse_version(){
  # get concourse version
  CO_VERSION=$(fly -t main sync | cut -d' ' -f2)
}

init_ssh(){
# configure ssh-agent to use the digitalocean private key and bypass hostkey verification
chmod 0600 $keys/id_rsa
trap 'kill $SSH_AGENT_PID' 0
ssh-add $keys/id_rsa >/dev/null
mkdir -p ~/.ssh
cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
chmod 0600 ~/.ssh/config
}
