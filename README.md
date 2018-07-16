Concourse DigitalOcean Worker Provision Resource
======================

A [Concourse](http://concourse.ci/) resource to dynamically provision droplets on DigitalOcean and configure them as workers to run pipeline job and destroy them after job is done.


## Limitations

- It's highly recommended to create and destroy the worker inside a job to always guarantee the destruction of the droplet using it under `ensure` step on the job level.

- Jobs with worker provisioning should limit running multiple builds of the same job in parallel using `serial: true` otherwise one build finish will destroy all the workers of all build for the same job causing them to hang, example of using serial:

```
jobs:
  - name: some-job
    serial: true
    plan:
      - ....
```

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
* `ci_worker_key`: _Required - (String)_. An ssh private key to be used by the worker to access TSA server, it should be previously added to CONCOURSE_TSA_AUTHORIZED_KEYS when configuring Concourse Web.
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

### `in`: Provision droplet and register as worker

[](TODO: write description)

##### Parameters

* `worker_name`: _Required - (String)_. A unique name across all pipelines for digitalocean account, must be valid hostname (contains alphanumerics and hyphens), this name should be used in tags on job steps to make them run on the provisioned worker (using the same name for multiple workers will cause one finished job to destroy all workers with the same name lead to other jobs running on the worker with the same name to hang).

### `out`: Destroy the droplet and prune the worker

[](TODO: write description)

##### Parameters

* `worker_name`: _Required - (String)_. A unique name across all pipelines for digitalocean account, must be valid hostname (contains alphanumerics and hyphens), this name should be used in tags on job steps to make them run on the provisioned worker (using the same name for multiple workers will cause one finished job to destroy all workers with the same name lead to other jobs running on the worker with the same name to hang) if you don't set this (and you're not encouraged at all to do so, it will default to: ci-worker-<PIPELINE_NAME>-<JOB_NAME>, ex: ci-worker-projectX-build).

## Example

> Adding example soon

## License

Apache License 2.0
