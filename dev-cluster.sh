
# USAGE :

# 1st argument - services
# 2nd argument - action
ACTION=$1
SERVICE=$2

# Actions : 

  # Setup - starts MK, define routes to PODs
  # Sync - deploys/updates your manifest and exports SERVICE_PORT variables
  # Teardown - destroys MK, gets rid of routes

# This is just a trick to handle differences in the "route" command
# which has different syntax in Linux and OSX
GW=""
if [ -f /etc/issue ] ; then
  GW="gw" 
fi

MKUBE_IP=$(minikube ip)

# Migrate this guy to setup/teardown
if [ -z "$ACTION" ] ; then
  echo "Please specify an action"
  echo "Usage: ./dev-cluster.sh [setup|sync <service_name>|teardown]"
  exit 13
fi
# On a similar note, only sync will require a service name :-)

function get_endpoint() {
  SERVICE=$1
  ENDPOINT=$(kubectl describe svc $SERVICE | grep Endpoint | head -n1 | awk -F':' '{print $2}' | sed 's/\s//g')
  echo $ENDPOINT
}

function setup { 
  # minikube start --extra-config=apiserver.ServiceNodePortRange=1000-40000
  # sleep 10
  # First, tell minikube to forward packets
  # between the networks it's in, so it acts as a router
  minikube ssh "sudo sysctl -w net.ipv4.ip_forward=1"
  
  # Then, set the host machine (user's laptop) routes to go there
  sudo route add -net 10.0.0.0/24 $GW $MKUBE_IP
  sudo route add -net 172.17.0.0/16 $GW $MKUBE_IP

  # Let's fill some environment variables with the IPs of the services of interest.
  # I wanted to tell the HOST machine to use MK's DNS but it causes too much trouble
  # to mess with resolv.conf in systemd/others days. Some of them almost bypass that file 
  export PIXY=$(get_endpoint "pixy")
  export COMET=$(get_endpoint "comet")
  export KAFKA=$(get_endpoint "kafka")
  export ZOOKEEPER=$(get_endpoint "zookeeper")
}

function apply {
  SERVICE=$1
  if [ -z "$SERVICE" ] ; then
    echo "Please specify a service. I don't want to apply them all :-/"
    echo "Usage: ./dev-cluster.sh [setup|sync <service_name>|teardown]"
    exit 13
  fi
  kubectl create -f services/$SERVICE/*.yaml
}

function sync {
  SERVICE=$2
  if [ -z "$SERVICE" ] ; then
    echo "Please specify a service. I don't want to sync them all :-/"
    echo "Usage: ./dev-cluster.sh [setup|sync <service_name>|teardown]"
    exit 13
  fi
  # Now we auto-discovery what are the services ports
}

function teardown {
  # Undo everything from the setup. Right now, not a lot :-)
  sudo route delete -net 10.0.0.0/24 $GW $MKUBE_IP
  sudo route delete -net 172.17.0.0/16 $GW $MKUBE_IP

  export PIXY=""
  export COMET=""
  export KAFKA=""
  export ZOOKEEPER=""
}

if [ $ACTION == "setup" ] ; then
  setup
fi
if [ $ACTION == "apply" ] ; then
  apply $SERVICE
fi
if [ $ACTION == "teardown" ] ; then
  teardown
fi

# Instructions :

# In the first iteration, this script will not handle Minikube OR manifest setup/teardown for you. Early adopters will not be able to "abstract this layer" and actually know what they're doing there.

# Not rocket science at all. To back that I'll add an appendix to this explaining how to do that.

# For now, I'll stick to the TL;DR :

#  * Setup your MiniKube : samir@host:~/code/go/kafka-to-comet$ minikube start --extra-config=apiserver.ServiceNodePortRange=1000-40000
#  * Use the manifest to create the cluster : samir@host:~/code/go/kafka-to-comet$ kubectl create -f manifests/kafka-to-comet-dev-cluster.yaml
#  * Wait a bit. Don't worry, it will take a while as we have 300 ms of latency to the registry. The network path crosses the atlantic 4x for whatever reason. Improvements are in the roadmap
#  * You can watch the status by periodically querying kubernetes with  : $ kubectl get all. Once you see all your pods "Running" at the top, you're good :
#  samir@darkstar:~/code/go/kafka-to-comet$ kubectl get all
#     NAME                            READY     STATUS              RESTARTS   AGE
#     po/kafka-0                      0/1       ContainerCreating   0          15m
#     po/ktc-1693751880-d4ppd         0/3       ContainerCreating   0          15m
#     po/zookeeper-3047500417-38232   1/1       Running             0          15m

#     NAME             CLUSTER-IP   EXTERNAL-IP   PORT(S)             AGE
#     svc/kafka        None         <none>        8000/TCP,9092/TCP   15m
#     svc/ktc          None         <none>        19091/TCP           15m
#     svc/kubernetes   10.0.0.1     <none>        443/TCP             17m
#     svc/zookeeper    None         <none>        2181/TCP,8000/TCP   15m

#     NAME                 DESIRED   CURRENT   AGE
#     statefulsets/kafka   1         0         15m

#     NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
#     deploy/ktc         1         1         1            0           15m
#     deploy/zookeeper   1         1         1            1           15m

#     NAME                      DESIRED   CURRENT   READY     AGE
#     rs/ktc-1693751880         1         1         0         15m
#     rs/zookeeper-3047500417   1         1         1         15m
#  * Once you see all the pods running, we can go to the next step and setup the environment to work with our application : 
#   samir@darkstar:~/code/go/kafka-to-comet$ source dev-cluster.sh setup
#   OR
#   samir@darkstar:~/code/go/kafka-to-comet$ . dev-cluster.sh setup
# You don't need to, but just so you know what it does -- it sets up routing TO kubernetes. so you can connect to pods/services directly (beautiful).
# It also sets up a few environment variables -- $PIXY and $COMET so that we can connect to these guys without having to do any DNS witchcraft or remember/know IPs.
# We did try and fail to mess with the host's machine DNS resolver. A ride that's not worth it unless you want to spend time supporting each OS's nuances.
#
# At this point, we should be ready to run our application, point to the endpoints we want and feed Kafka with some data :
#
# samir@darkstar:/usr/lib/go/src/kafka-to-comet$ go run main.go  -addr $PIXY:19091 -cometAddr $COMET:8090
# samir@darkstar:~/opt/kafka_2.10-0.10.2.1$ bin/kafka-console-producer.sh --topic test --broker-list $ZOOKEEPER:2181



 
