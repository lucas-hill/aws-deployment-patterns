# cloud-deploy-practice

A minimal Go HTTP API used as a learning vehicle for deploying to AWS three different ways: EC2, ECS, and EKS.

The app deliberately stays simple — the point is the infrastructure around it, not the application logic.

## Endpoints

| Method | Path     | Description                              |
|--------|----------|------------------------------------------|
| GET    | /        | Root — returns app info                  |
| GET    | /health  | Health check (used by load balancers)    |
| GET    | /items   | List all items (in-memory store)         |
| POST   | /items   | Create an item — body: `{"name": "..."}` |

## Configuration

The app reads these environment variables:

| Variable    | Default   | Purpose                                |
|-------------|-----------|----------------------------------------|
| `PORT`      | `8080`    | Port the HTTP server listens on        |
| `APP_ENV`   | `local`   | Free-form environment label            |
| `LOG_LEVEL` | `info`    | `debug` / `info` / `warn` / `error`    |

## Running locally

### Option A — directly with Go (fastest iteration)

```bash
cd app
go run .
```

### Option B — in a container (matches what AWS will run)

```bash
docker compose up --build
```

## Testing the endpoints

Once the server is running on `:8080`:

```bash
# Health check
curl http://localhost:8080/health

# Root
curl http://localhost:8080/

# List items (empty at first)
curl http://localhost:8080/items

# Create an item
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name": "first item"}'

# List again
curl http://localhost:8080/items
```

## Deployment

See `deploy/ec2/`, `deploy/ecs/`, and `deploy/eks/` for each deployment strategy.
