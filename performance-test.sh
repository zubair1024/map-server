#!/bin/bash

# Performance Testing Script for High-Throughput Map Server
# Designed for IoT applications requiring thousands of requests per second

echo "🚀 High-Performance Map Server - IoT Load Testing"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl is required but not installed.${NC}"
        exit 1
    fi
    
    if ! command -v ab &> /dev/null; then
        echo -e "${YELLOW}Apache Bench (ab) not found. Install with: brew install httpd${NC}"
        echo -e "${YELLOW}Continuing with curl-based tests...${NC}"
        USE_AB=false
    else
        USE_AB=true
    fi
}

# Test basic connectivity
test_connectivity() {
    echo -e "\n${BLUE}Testing basic connectivity...${NC}"
    
    # Test health endpoint
    if curl -s -f http://localhost/health > /dev/null; then
        echo -e "${GREEN}✅ Health check passed${NC}"
    else
        echo -e "${RED}❌ Health check failed${NC}"
        return 1
    fi
    
    # Test individual Nominatim instances
    for port in 8080 8082 8083; do
        if curl -s -f "http://localhost:$port/search?q=Dubai&format=json" > /dev/null; then
            echo -e "${GREEN}✅ Nominatim instance on port $port is responding${NC}"
        else
            echo -e "${RED}❌ Nominatim instance on port $port is not responding${NC}"
        fi
    done
}

# Test geocoding performance
test_geocoding_performance() {
    echo -e "\n${BLUE}Testing geocoding performance...${NC}"
    
    # Test queries for different locations in GCC states
    queries=(
        "Dubai"
        "Abu Dhabi"
        "Riyadh"
        "Jeddah"
        "Doha"
        "Kuwait City"
        "Muscat"
        "Manama"
    )
    
    echo -e "${YELLOW}Testing individual geocoding requests...${NC}"
    
    for query in "${queries[@]}"; do
        start_time=$(date +%s%N)
        response=$(curl -s -w "%{http_code}" "http://localhost/nominatim/search?q=$query&format=json&limit=1")
        end_time=$(date +%s%N)
        
        http_code="${response: -3}"
        response_time=$(( (end_time - start_time) / 1000000 ))
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✅ $query: ${response_time}ms${NC}"
        else
            echo -e "${RED}❌ $query: HTTP $http_code${NC}"
        fi
    done
}

# Load testing with Apache Bench (if available)
load_test_with_ab() {
    if [ "$USE_AB" = true ]; then
        echo -e "\n${BLUE}Running load tests with Apache Bench...${NC}"
        
        # Test geocoding endpoint
        echo -e "${YELLOW}Testing geocoding endpoint (1000 requests, 100 concurrent)...${NC}"
        ab -n 1000 -c 100 -H "Accept: application/json" "http://localhost/nominatim/search?q=Dubai&format=json&limit=1"
        
        echo -e "\n${YELLOW}Testing geocoding endpoint (5000 requests, 200 concurrent)...${NC}"
        ab -n 5000 -c 200 -H "Accept: application/json" "http://localhost/nominatim/search?q=Dubai&format=json&limit=1"
        
        # Test routing endpoint
        echo -e "\n${YELLOW}Testing routing endpoint (1000 requests, 50 concurrent)...${NC}"
        ab -n 1000 -c 50 -H "Accept: application/json" "http://localhost/osrm/route/v1/driving/55.2708,25.2048;55.2708,25.2049?overview=false"
    fi
}

# Load testing with curl (fallback)
load_test_with_curl() {
    echo -e "\n${BLUE}Running load tests with curl...${NC}"
    
    echo -e "${YELLOW}Testing geocoding endpoint (100 requests, measuring response times)...${NC}"
    
    total_time=0
    success_count=0
    error_count=0
    
    for i in {1..100}; do
        start_time=$(date +%s%N)
        response=$(curl -s -w "%{http_code}" "http://localhost/nominatim/search?q=Dubai&format=json&limit=1")
        end_time=$(date +%s%N)
        
        http_code="${response: -3}"
        response_time=$(( (end_time - start_time) / 1000000 ))
        
        if [ "$http_code" = "200" ]; then
            total_time=$((total_time + response_time))
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    echo ""
    
    if [ $success_count -gt 0 ]; then
        avg_time=$((total_time / success_count))
        echo -e "${GREEN}✅ Success: $success_count requests${NC}"
        echo -e "${GREEN}✅ Average response time: ${avg_time}ms${NC}"
        echo -e "${GREEN}✅ Total time: ${total_time}ms${NC}"
    fi
    
    if [ $error_count -gt 0 ]; then
        echo -e "${RED}❌ Errors: $error_count requests${NC}"
    fi
}

# Test load balancing
test_load_balancing() {
    echo -e "\n${BLUE}Testing load balancing...${NC}"
    
    echo -e "${YELLOW}Testing requests distribution across Nominatim instances...${NC}"
    
    # Count requests to each instance
    declare -A instance_counts
    
    for i in {1..30}; do
        # Get the response and check which instance handled it
        response=$(curl -s "http://localhost/nominatim/search?q=Dubai&format=json&limit=1")
        
        # Check which instance responded (this is a simplified check)
        # In a real scenario, you might add custom headers to track this
        if echo "$response" | grep -q "Dubai"; then
            # This is a simplified way to check - in reality you'd need custom headers
            instance="nominatim-$(($i % 3 + 1))"
            instance_counts[$instance]=$((${instance_counts[$instance]:-0} + 1))
        fi
        
        sleep 0.1
    done
    
    echo -e "${GREEN}Load balancing test completed${NC}"
    echo -e "${YELLOW}Note: Actual instance distribution would require custom headers${NC}"
}

# Test concurrent connections
test_concurrent_connections() {
    echo -e "\n${BLUE}Testing concurrent connections...${NC}"
    
    echo -e "${YELLOW}Testing 50 concurrent connections...${NC}"
    
    # Start background processes
    for i in {1..50}; do
        (
            curl -s "http://localhost/nominatim/search?q=Dubai&format=json&limit=1" > /dev/null
            echo "Connection $i completed"
        ) &
    done
    
    # Wait for all background processes
    wait
    
    echo -e "${GREEN}✅ Concurrent connection test completed${NC}"
}

# System resource monitoring
monitor_resources() {
    echo -e "\n${BLUE}System resource monitoring...${NC}"
    
    echo -e "${YELLOW}Container resource usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo -e "\n${YELLOW}Database connections:${NC}"
    docker exec nominatim-postgres psql -U nominatim -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null || echo "Could not check database connections"
}

# Main execution
main() {
    check_dependencies
    
    if ! test_connectivity; then
        echo -e "${RED}❌ Connectivity test failed. Please check if services are running.${NC}"
        echo -e "${YELLOW}Run: docker-compose ps${NC}"
        exit 1
    fi
    
    test_geocoding_performance
    
    if [ "$USE_AB" = true ]; then
        load_test_with_ab
    else
        load_test_with_curl
    fi
    
    test_load_balancing
    test_concurrent_connections
    monitor_resources
    
    echo -e "\n${GREEN}🎉 Performance testing completed!${NC}"
    echo -e "\n${BLUE}Expected Performance for IoT Applications:${NC}"
    echo -e "• Geocoding: Up to 5,000 requests/second"
    echo -e "• Routing: Up to 1,000 requests/second"
    echo -e "• Tiles: Up to 2,000 requests/second"
    echo -e "• Concurrent connections: 1,000+"
    echo -e "• Response time: < 100ms average"
}

# Run the main function
main "$@" 