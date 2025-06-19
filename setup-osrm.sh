#!/bin/bash

# OSRM Data Setup Script for GCC States
echo "Setting up OSRM routing data for GCC States..."

# Create a temporary container to download and process data
echo "Downloading GCC States OSM data..."
docker run --rm -v osrm_data:/data osrm/osrm-backend:latest sh -c "
    cd /data &&
    curl -L -o gcc-states-latest.osm.pbf https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf &&
    echo 'Extracting routing data...' &&
    osrm-extract -p /opt/car.lua gcc-states-latest.osm.pbf &&
    echo 'Partitioning data...' &&
    osrm-partition gcc-states-latest.osrm &&
    echo 'Customizing data...' &&
    osrm-customize gcc-states-latest.osrm &&
    echo 'Cleaning up...' &&
    rm gcc-states-latest.osrm gcc-states-latest.osrm.restrictions gcc-states-latest.osrm.cnbg gcc-states-latest.osrm.cnbg_to_ebg gcc-states-latest.osrm.ebg gcc-states-latest.osrm.ebg_nodes gcc-states-latest.osrm.enw gcc-states-latest.osrm.fileIndex gcc-states-latest.osrm.geometry gcc-states-latest.osrm.icd gcc-states-latest.osrm.level gcc-states-latest.osrm.maneuver gcc-states-latest.osrm.mldgr gcc-states-latest.osrm.names gcc-states-latest.osrm.nbg_nodes gcc-states-latest.osrm.partition gcc-states-latest.osrm.ramIndex gcc-states-latest.osrm.timestamp gcc-states-latest.osrm.tld gcc-states-latest.osrm.tls gcc-states-latest.osrm.turn_duration_penalties gcc-states-latest.osrm.turn_weight_penalties gcc-states-latest.osrm.way_category gcc-states-latest.osrm.way_weights &&
    echo 'OSRM data setup complete!'
"

echo "Restarting OSRM container to use new data..."
docker-compose restart osrm

echo "Waiting for OSRM to start..."
sleep 10

echo "Testing OSRM routing..."
curl -f "http://localhost:5001/route/v1/driving/55.2708,25.2048;55.2708,25.2049?overview=false" || echo "OSRM not ready yet, check logs with: docker logs osrm-routing"

echo "OSRM setup complete! You can now use routing at:"
echo "- Direct: http://localhost:5001/"
echo "- Via proxy: http://localhost/osrm/" 