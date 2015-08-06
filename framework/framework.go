package main

import (
	"flag"
	"os"
	"strconv"

	log "github.com/Sirupsen/logrus"
	"github.com/basho-labs/riak-mesos/scheduler"
)

var (
	mesosMaster       string
	zookeeperAddr     string
	schedulerHostname string
	schedulerIPAddr   string
	frameworkName     string
	user              string
	logFile           string
)

func init() {
	flag.StringVar(&mesosMaster, "master", "zk://33.33.33.2:2181/mesos", "Mesos master")
	flag.StringVar(&zookeeperAddr, "zk", "33.33.33.2:2181", "Zookeeper")
	flag.StringVar(&schedulerHostname, "hostname", "", "Framework hostname")
	flag.StringVar(&schedulerIPAddr, "ip", "33.33.33.1", "Framework ip")
	flag.StringVar(&frameworkName, "name", "riak-mesos-go3", "Framework Instance Name")
	flag.StringVar(&user, "user", "", "Framework Username")
	flag.StringVar(&logFile, "log", "", "Log File Location")
	flag.Parse()
}

func main() {
	log.SetLevel(log.DebugLevel)

	fo, logErr := os.Create(logFile)
	if logErr != nil {
		panic(logErr)
	}
	log.SetOutput(fo)

	// When starting scheduler from Marathon, PORT0-N env vars will be set
	rexPortStr := os.Getenv("PORT1")

	// If PORT1 isn't set, fallback to a hardcoded one for now
	// TODO: Sargun fix me
	if rexPortStr == "" {
		rexPortStr = "9090"
	}

	rexPort, portErr := strconv.Atoi(rexPortStr)
	if portErr != nil {
		log.Fatal(portErr)
	}

	sched := scheduler.NewSchedulerCore(schedulerHostname, frameworkName, []string{zookeeperAddr}, schedulerIPAddr, user, rexPort)
	sched.Run(mesosMaster)
}
