# Map Server Stack

A complete Docker-based mapping stack featuring Nominatim (geocoding), OSRM (routing), and Tegola (tile server) with GCC states map data from Geofabrik.

## Services

- **Nominatim** (Port 8080): Geocoding and reverse geocoding service
- **OSRM** (Port 5001): High-performance routing engine
- **Tegola** (Port 8081): Vector tile server
- **PostgreSQL** (Port 5432): Database for Nominatim and tile data
- **Nginx** (Port 80): Reverse proxy with rate limiting and caching

## GCC States Coverage

This setup uses the GCC (Gulf Cooperation Council) states map data from Geofabrik, which includes:

- Bahrain
- Kuwait
- Oman
- Qatar
- Saudi Arabia
- United Arab Emirates

## Quick Start

1. **Start the services:**

   ```bash
   docker-compose up -d
   ```

2. **Monitor the startup process:**

   ```bash
   docker-compose logs -f
   ```

3. **Check service health:**
   ```bash
   curl http://localhost/health
   ```

## API Endpoints

### Nominatim (Geocoding)

- **Forward geocoding:** `GET /nominatim/search?q=query`
- **Reverse geocoding:** `GET /nominatim/reverse?lat=25.2048&lon=55.2708&format=json`

### OSRM (Routing)

- **Route calculation:** `GET /osrm/route/v1/driving/55.2708,25.2048;55.2708,25.2049`
- **Matrix calculation:** `GET /osrm/table/v1/driving/55.2708,25.2048;55.2708,25.2049`

### Tegola (Tiles)

- **Tile endpoint:** `GET /tiles/osm/{z}/{x}/{y}.pbf`
- **Capabilities:** `GET /tiles/capabilities/osm.json`

## Initial Setup

The first startup will take significant time as it:

1. Downloads the GCC states OSM data (~100-200MB)
2. Imports data into PostgreSQL for Nominatim
3. Processes OSM data for OSRM routing
4. Sets up tile server layers

**Expected setup time:** 30-60 minutes depending on your system.

## Updating Map Data

### Overview

Map data can be updated in two ways:

1. **Automatic updates** via Nominatim's replication system
2. **Manual updates** by downloading fresh OSM data

### Method 1: Automatic Updates (Recommended)

Nominatim automatically handles incremental updates from OpenStreetMap.

#### Check Update Status

```bash
# Check if updates are running
docker exec nominatim ps aux | grep update

# Check last update time
docker exec nominatim-postgres psql -U nominatim -c "SELECT lastimportdate FROM import_status;"
```

#### Manual Update Trigger

```bash
# Trigger an update
docker exec nominatim /app/utils/update.php --import-osmosis-all

# Check update progress
docker-compose logs -f nominatim
```

### Method 2: Manual Full Data Update

For complete data refresh or switching to different regions.

#### Step 1: Stop Services

```bash
# Stop all services
docker-compose down

# Remove old data volumes (optional - will force complete rebuild)
docker volume rm map-server_nominatim_data map-server_osrm_data
```

#### Step 2: Update OSM Data Source (Optional)

Edit `docker-compose.yml` to change the data source:

```yaml
environment:
  PBF_URL: https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf
  # Change to other regions:
  # PBF_URL: https://download.geofabrik.de/europe/germany-latest.osm.pbf
  # PBF_URL: https://download.geofabrik.de/north-america/us-latest.osm.pbf
```

#### Step 3: Restart Services

```bash
# Start services with fresh data
docker-compose up -d

# Monitor the import process
docker-compose logs -f nominatim
```

### Method 3: OSRM Data Update Only

If you only need to update routing data without affecting geocoding.

#### Step 1: Download New OSM Data

```bash
# Download fresh OSM data
curl -L -o gcc-states-latest.osm.pbf https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf
```

#### Step 2: Copy to OSRM Volume

```bash
# Copy the file to the OSRM data volume
docker cp gcc-states-latest.osm.pbf osrm-routing:/data/
```

#### Step 3: Process OSRM Data

```bash
# Extract routing data
docker run --rm -v map-server_osrm_data:/data osrm/osrm-backend:latest osrm-extract -p /opt/car.lua /data/gcc-states-latest.osm.pbf

# Partition the data
docker run --rm -v map-server_osrm_data:/data osrm/osrm-backend:latest osrm-partition /data/gcc-states-latest.osrm

# Customize the data
docker run --rm -v map-server_osrm_data:/data osrm/osrm-backend:latest osrm-customize /data/gcc-states-latest.osrm
```

#### Step 4: Restart OSRM Service

```bash
# Restart OSRM to use new data
docker-compose restart osrm

# Test the routing service
curl -f "http://localhost:5001/route/v1/driving/55.2708,25.2048;55.2708,25.2049?overview=false"
```

### Method 4: Automated Update Script

Use the provided script for complete OSRM data update:

```bash
# Make script executable
chmod +x setup-osrm.sh

# Run the update
./setup-osrm.sh
```

### Update Verification

After any update, verify all services are working:

```bash
# Check all services health
docker-compose ps

# Test health endpoint
curl http://localhost/health

# Test geocoding
curl "http://localhost/nominatim/search?q=Dubai&format=json" | head -c 200

# Test routing
curl -f "http://localhost/osrm/route/v1/driving/55.2708,25.2048;55.2708,25.2049?overview=false"

# Test tile server
curl -f http://localhost:8081/capabilities
```

### Data Sources

Available OSM data sources from Geofabrik:

- **GCC States**: `https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf`
- **UAE Only**: `https://download.geofabrik.de/asia/united-arab-emirates-latest.osm.pbf`
- **Saudi Arabia**: `https://download.geofabrik.de/asia/saudi-arabia-latest.osm.pbf`
- **Qatar**: `https://download.geofabrik.de/asia/qatar-latest.osm.pbf`
- **Kuwait**: `https://download.geofabrik.de/asia/kuwait-latest.osm.pbf`
- **Oman**: `https://download.geofabrik.de/asia/oman-latest.osm.pbf`
- **Bahrain**: `https://download.geofabrik.de/asia/bahrain-latest.osm.pbf`

### Update Frequency

- **Nominatim**: Updates automatically every few hours
- **OSRM**: Manual updates recommended monthly or when needed
- **Tegola**: Uses Nominatim database, updates automatically

## Configuration

### Environment Variables

Key environment variables you can modify in `docker-compose.yml`:

- `PBF_URL`: OSM data source URL
- `POSTGRES_SHARED_BUFFERS`: Database memory allocation
- `POSTGRES_EFFECTIVE_CACHE_SIZE`: Database cache size

### Volume Mounts

- `postgres_data`: PostgreSQL database files
- `nominatim_data`: Nominatim database files
- `nominatim_import`: OSM import files
- `osrm_data`: OSRM processed data
- `tegola_cache`: Tile cache

## Performance Tuning

The configuration is optimized for:

- **Memory:** 8GB+ RAM recommended
- **Storage:** 50GB+ free space
- **CPU:** 4+ cores recommended

### Database Tuning

PostgreSQL is configured with:

- Shared buffers: 2GB
- Effective cache size: 24GB
- Work memory: 50MB
- Maintenance work memory: 10GB

## Monitoring

### Health Checks

All services include health checks:

```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs nominatim
docker-compose logs osrm
docker-compose logs tegola
```

### Performance Monitoring

```bash
# Database connections
docker exec nominatim-postgres psql -U nominatim -c "SELECT count(*) FROM pg_stat_activity;"

# Disk usage
docker system df
```

## Troubleshooting

### Common Issues

1. **Out of memory errors:**

   - Reduce `POSTGRES_SHARED_BUFFERS` and `POSTGRES_EFFECTIVE_CACHE_SIZE`
   - Ensure sufficient swap space

2. **Import failures:**

   - Check available disk space
   - Verify internet connection for data download
   - Check logs: `docker-compose logs nominatim`

3. **Service not responding:**

   - Check health status: `docker-compose ps`
   - Restart service: `docker-compose restart [service-name]`

4. **OSRM data not found:**
   - Verify OSRM data files exist: `docker exec osrm-routing ls -lh /data/`
   - Re-run OSRM processing steps if needed
   - Check OSRM logs: `docker logs osrm-routing`

### Reset Everything

```bash
# Stop and remove everything
docker-compose down -v

# Remove all images
docker system prune -a

# Start fresh
docker-compose up -d
```

## Development

### Adding Custom Data

1. Place your OSM PBF file in the project directory
2. Update `PBF_URL` in `docker-compose.yml`
3. Restart services: `docker-compose restart`

### Custom Tile Styles

Modify `tegola-config/config.toml` to add custom layers or change styling.

## License

This setup uses:

- OpenStreetMap data (ODbL license)
- Nominatim (GPL v2)
- OSRM (BSD 2-clause)
- Tegola (MIT)

## Support

For issues specific to:

- **Nominatim:** [GitHub Issues](https://github.com/osm-search/Nominatim/issues)
- **OSRM:** [GitHub Issues](https://github.com/Project-OSRM/osrm-backend/issues)
- **Tegola:** [GitHub Issues](https://github.com/go-spatial/tegola/issues)
