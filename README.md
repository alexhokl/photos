# photos
Personal photo management

## Configuration

Configuration can be specified via command-line flags, environment variables
(prefixed with `PHOTOS_`), or a YAML configuration file.

The default configuration file path is `~/.photos.yaml`.

### Example `~/.photos.yaml`

```yaml
# Global options
service: photos.example.ts.net:8080
insecure: false

# Server options (used by "photos serve")
port: 8080
proxy_port: 8081
database: /path/to/photos.db
hostname: photos
ts_auth_key: tskey-auth-xxxxx
ts_state_dir: ./tailscale-state
gcs_bucket: my-photos-bucket
gcs_project: my-gcp-project
gcs_credentials: /path/to/credentials.json
gcs_prefix: photos/
```
