# --- Stage 1: Build Phase ---
FROM maven:3.8.8-eclipse-temurin-8 AS builder

# Set the working directory
WORKDIR /usr/src/easybuggy

# Copy the pom.xml and source code
COPY . .

# Build the WAR file and skip tests to save time/space
RUN mvn clean package -DskipTests

# --- Stage 2: Runtime Phase ---
# We use Jetty because EasyBuggy is a WAR-based application
FROM jetty:9.4-jre8-slim

# Set working directory for the server
WORKDIR /var/lib/jetty

# Create a logs directory for the GC and Derby logs
USER root
RUN mkdir -p /var/lib/jetty/logs && chown -R jetty:jetty /var/lib/jetty/logs
USER jetty

# Copy the WAR file from the builder stage into Jetty's webapps folder
# Renaming it to ROOT.war makes it available at the root URL (/)
COPY --from=builder /usr/src/easybuggy/target/*.war /var/lib/jetty/webapps/root.war

# Set your specific performance and debug flags as Environment Variables
# Jetty automatically picks up JAVA_OPTIONS
ENV JAVA_OPTIONS="\
    -XX:MaxMetaspaceSize=128m \
    -Xloggc:logs/gc_%p_%t.log \
    -Xmx256m \
    -XX:MaxDirectMemorySize=90m \
    -XX:+UseSerialGC \
    -XX:+PrintHeapAtGC \
    -XX:+PrintGCDetails \
    -XX:+PrintGCDateStamps \
    -XX:+UseGCLogFileRotation \
    -XX:NumberOfGCLogFiles=5 \
    -XX:GCLogFileSize=10M \
    -XX:GCTimeLimit=15 \
    -XX:GCHeapFreeLimit=50 \
    -XX:+HeapDumpOnOutOfMemoryError \
    -XX:HeapDumpPath=logs/ \
    -XX:ErrorFile=logs/hs_err_pid%p.log \
    -Dderby.stream.error.file=logs/derby.log \
    -Dderby.infolog.append=true \
    -Dderby.language.logStatementText=true \
    -Dderby.locks.deadlockTrace=true \
    -Dderby.locks.monitor=true \
    -Dderby.storage.rowLocking=true \
    -Dcom.sun.management.jmxremote \
    -Dcom.sun.management.jmxremote.port=7900 \
    -Dcom.sun.management.jmxremote.ssl=false \
    -Dcom.sun.management.jmxremote.authenticate=false \
    -ea"

# Expose the standard Jetty port
EXPOSE 8080
