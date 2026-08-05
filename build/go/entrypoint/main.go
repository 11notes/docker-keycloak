package main

import (
	"os"
	"github.com/11notes/go-eleven"
)

const APP_JAR string = "/opt/keycloak/lib/quarkus-run.jar"

func main() {
	if(len(os.Args) > 1){
		args := os.Args[1:]
		switch args[0] {
			default:
				start()
		}
	}else{
		start()
	}
}

func start(){
	// start keycloak
	eleven.Container.Run("/opt/jre-minimal/bin", "java", []string{"-Xms64m", "-Xmx512m", "-Djava.security.egd=file:/dev/urandom", "-Dkc.home.dir=/opt/keycloak", "-Dkeycloak.platform.name=...", "-Djboss.server.config.dir=/keycloak/etc", "-jar", APP_JAR, "start"}, []string{"CLASSPATH_OPTS=" + APP_JAR})
}