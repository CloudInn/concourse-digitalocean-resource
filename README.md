Concourse DigitalOcean Worker Provision Resource
======================

A [Concourse](http://concourse.ci/) resource to minimize CI infrastructure cost by dynamically provision droplets on DigitalOcean and configure them as workers to run pipeline job and destroy them after the job is done (DigitalOcean charges you per hour).

> **Note:** This resource is tested on Concourse v3.13.0 and will mostly work on any 3.xx version, but it does not support version 4.00 and higher yet (it has not been tested on it).

## Limitations

- You'll need at least one Linux worker to be used by the resource to provision more workers

- It's highly recommended to create and destroy the worker inside the same job to always guarantee the destruction of the droplet, to achieve so use `get` (destroys worker) under `ensure` step on the job level to make sure the droplet is always destroyed no matter the job passed or failed.

- Jobs with worker provisioning should limit running multiple builds of the same job in parallel using `serial: true` otherwise one build finish will destroy all the workers of all build for the same job causing them to hang, example of using serial:

```
jobs:
  - name: some-job
    serial: true
    plan:
      - ....
```

## Preparations

- Generate API Key from your DigitalOcean account to be passed as `api_key` in source
- Generate an ssh private key to be passed as `droplet_key` in source (will be used by the resource to configure the created droplets).
- Get Concourse TSA public key to be passed as `ci_tsa_pub_key` in source
- Get the worker private key to be passed as `ci_worker_key` in srouce, this key should already have its public key added to Concourse web under TSA authorized keys.
- Optional, you select the region and droplet size to be used as worker, you can obtain a full list using [DigitalOcean API](https://developers.digitalocean.com/documentation/v2/)

## Resource Type Configuration

```yaml
resource_types:
  - name: worker-resource
    type: docker-image
    source:
      repository: cloudinn/concourse-digitalocean-resource
      tag: latest
```

## Source Configuration

* `api_key`: _Required - (String)_. A DigitalOcean API key, you can get it through your DigitalOcean account setting.
* `region`: _Optional - (String)_. You can get the list of valid regions through [DigitalOcean API](https://developers.digitalocean.com/documentation/v2/) (default: `ams3`)
* `droplet_size`: _Optional - (String)_. You can get the list of valid sizes on selected region through [DigitalOcean API](https://developers.digitalocean.com/documentation/v2/) (default `s-2vcpu-2gb`)
* `droplet_kay`: _Required - (String)_. A generated ssh private key used to access the newly created droplets, the key will be used to generate public key and add it to DigitalOcean account add it to the created droplets to be able to access and install and configure concourse worker on them.
* `ci_worker_key`: _Required - (String)_. An ssh private key to be used by the worker to access TSA server, its public key should be previously added to CONCOURSE_TSA_AUTHORIZED_KEYS when configuring Concourse Web.
* `ci_tsa_pub_key`: _Required - (String)_. The public key of the key set in CONCOURSE_TSA_HOST_KEY in Concourse Web, to allow TSA to access this worker.
* `ci_tsa_port`: _Optional - (String)_. Set this if you're using custom TSA port change (default: `2222`)
* `fly_username`: _Required - (String)_. The username of Concourse basic auth, to allow using `fly prune-worker` command to make sure the worker is removed from TSA workers registry when it's destroyed.
* `fly_password`: _Required - (String)_. Concourse Web basic auth password for the previous username.


```yaml
resources:
- name: worker
  type: worker-resource
  source:
    api_key: ((DO_API_KEY))
    region: "ams3"
    droplet_size: "s-2vcpu-2gb"
    droplet_kay: ((DO_DROPLET_KEY))
    ci_worker_key: ((CONCOURSE_WORKER_KEY))
    ci_tsa_pub_key: ((CONCOURSE_TSA_PUBKEY))
    ci_tsa_port: 2222
    fly_username: ((CONCOURSE_BASIC_AUTH_USER))
    fly_password: ((CONCOURSE_BASIC_AUTH_PASS))
```

## Behaviour

### `check`: Non-functional

### `out` (put): Provision droplet and register as worker

Provision worker with the given name (tag) that can be used to tag later steps to run on the created worker.

> You might want to use `timeout` step modifier with `3.5m` in this resource put step to avoid the rare case when DigitalOcean API fails creating the worker or taking so long (Usually if it takes more then 3.5 minutes then it's bugged)

##### params

* `worker_name`: _Required - (String)_. A unique name across all pipelines for digitalocean account, must be valid hostname (contains alphanumerics and hyphens), this name should be used in tags on later job steps to make them run on the provisioned worker (using the same name for workers in multiple jobs running in parallel will cause one finished job to destroy all workers with the same name that are running other jobs, leads to other jobs running on the worker with the same name to hang).

##### get_params

* `dont_destroy`:  _Required - (Boolean)_. You must always set to `true`. Concourse by default does implicit get after put to any resource, this behavior will lead to destroy the worker we just created, this parameter is used by the resource to prevent this behavior. If you don't pass it the put step won't fail but the worker will get instantly destroyed after it's created what makes the resource useless.

### `in` (get): Destroy the droplet and prune the worker

Destroy the created droplet and prune the worker from Concourse registry, this step shouldn't be executed on the same worker being destroyed.

##### params

* `worker_name`: _Required - (String)_. A unique name across all pipelines for digitalocean account, must be valid hostname (contains alphanumerics and hyphens), this name should be used in tags on later job steps to make them run on the provisioned worker (using the same name for workers in multiple jobs running in parallel will cause one finished job to destroy all workers with the same name that are running other jobs, leads to other jobs running on the worker with the same name to hang).


## Example

```yaml
resource_types:
- name: worker-resource
  type: docker-image
  source:
    repository: cloudinn/concourse-digitalocean-resource
    tag: latest

resources:
- name: worker
  type: worker-resource
  source:
    api_key: ((DO_API_KEY))
    region: "ams3"
    droplet_size: "s-2vcpu-2gb"
    ci_worker_key: ((CONCOURSE_WORKER_KEY))
    ci_tsa_pub_key: ((CONCOURSE_TSA_PUB_KEY))
    fly_username: ((FLY_USERNAME))
    fly_password: ((FLY_PASSWORD))
    droplet_key: ((DO_VM_KEY))

jobs:
  - name: build
    serial: true
    plan:
      - put: worker
        timeout: 3.5m
        params:
          worker_name: job-x-build-worker
        get_params:
          dont_destroy: true

      - task: some-task
        tags: [job-x-build-worker]
        config:
          platform: linux
          image_resource:
            type: docker-image
            source:
              repository: alpine
          run:
            path: sh
            args:
              - -exc
              - |
                echo "A task/step running on: job-x-build-worker"

    ensure:
      get: worker
      params:
        worker_name: job-x-build-worker
```

## License

Apache License 2.0
