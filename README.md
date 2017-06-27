# Local development cluster setup in Kubernetes
### Pre-requisites : 
 * Virtualbox (link)
 * Minikube (link)
 * Kubectl (link)

### In a few quick steps :

Start Minikube, the option to make the port range more wide is pretty useful :

```
$ minikube start --extra-config=apiserver.ServiceNodePortRange=1000-40000
```

That will take a minute or 2, not too bad. Then apply the manifest (definition) of your favorite service : 

```
samir@host:~/code/go/kafka-to-comet$ kubectl create -f manifests/kafka-to-comet-dev-cluster.yaml
```

This is out of scope but convenient to mention here - check the status of your deployment with this :

```
samir@host:~/code/go/kafka-to-comet$ kubectl get all
```

At some point we'll be ready to connect to the services. Here's how you benefit from the service/port auto-discovery from our toolkit :

```
samir@host:~/code/a-i-l$ source dev-cluster.sh setup
Setting up COMET_COMET - 172.17.0.10:8090
Setting up KAFKA_KONTROL - 172.17.0.2:8000
Setting up KAFKA_KAKFA - 172.17.0.2:9092
Setting up KUBERNETES_HTTPS - 10.0.2.15:443
Setting up PIXY_PIXY - 172.17.0.10:19091
Setting up ZOOKEEPER_ZOOKEEPER - 172.17.0.7:2181
Setting up ZOOKEEPER_KONTROL - 172.17.0.7:8000
```

As you might figure, this sets one environment variable per SERVICE + PORT combination. the value is the endpoint that you can connect to.

Note that the script also sets up the routing to the pod's subnet, so you can actually connect to them directly, without having to expose ports in Kubernetes. Added convenience.

Once you're done doing your thing, feel free to teardown, delete the manifest and shutdown the Minikube, on this order : 

```
samir@host:~/code/a-i-l$ source dev-cluster.sh teardown
Forgetting about COMET_COMET
Forgetting about KAFKA_KONTROL
Forgetting about KAFKA_KAKFA
Forgetting about KUBERNETES_HTTPS
Forgetting about PIXY_PIXY
Forgetting about ZOOKEEPER_ZOOKEEPER
Forgetting about ZOOKEEPER_KONTROL

samir@host:~/code/go/kafka-to-comet$ kubectl delete -f manifests/kafka-to-comet-dev-cluster.yaml

samir@host:~/code/a-i-l$ minikube delete
```
The order is important as there are some discoveries in place that still need the underlying service running so that they can work.
