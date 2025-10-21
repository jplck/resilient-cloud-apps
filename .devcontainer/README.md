# Devcontainer README

## Getting Started with the Development Container

This devcontainer provides a complete development environment for the Resilient Cloud Apps solution, including:

- .NET 7.0 SDK
- Azure CLI with extensions
- Docker-in-Docker support
- Node.js 18 (for Blazor WebAssembly development)
- Essential VS Code extensions for .NET and Azure development

### Prerequisites

- Docker Desktop installed and running
- VS Code with the Dev Containers extension
- Git

### Opening the Project

1. Clone the repository
2. Open VS Code and run the command: `Dev Containers: Reopen in Container`
3. Wait for the container to build and the post-create script to complete

### Environment Setup

1. Copy the environment template:
   ```bash
   cp .devcontainer/.env.template .env
   ```

2. Update the `.env` file with your Azure credentials and connection strings

3. If you have Azure CLI logged in on your host machine, you can authenticate:
   ```bash
   az login
   ```

### Building and Running

The solution includes multiple projects. You can use the provided VS Code tasks or run them manually:

#### Using VS Code Tasks
- Open Command Palette (`Ctrl+Shift+P`)
- Select "Tasks: Run Task"
- Choose from available build tasks

#### Manual Commands
```bash
# Build entire solution
dotnet build src/apps.sln

# Run individual projects
dotnet run --project src/Contonance.Backend
dotnet run --project src/Contonance.WebPortal/Server
dotnet run --project src/EnterpriseWarehouse.Backend
```

### Available Ports

The following ports are automatically forwarded:
- `5000` - Backend HTTP
- `5001` - Backend HTTPS  
- `5173` - Blazor WebAssembly dev server
- `7071` - Azure Functions (if used)

### Debugging

- Set breakpoints in your C# code
- Use F5 to start debugging
- Multiple launch configurations are available in `.vscode/launch.json`

### Azure Development

The container includes Azure CLI and relevant extensions. To deploy infrastructure:

```bash
# Login to Azure
az login

# Deploy infrastructure
./deploy-infra.sh
```

### Docker Support

Docker-in-Docker is enabled, allowing you to build and run containers from within the devcontainer:

```bash
# Build a project's Docker image
docker build -f src/Contonance.Backend/Dockerfile .
```

### Troubleshooting

#### Container won't start
- Ensure Docker Desktop is running
- Check that no other containers are using the same ports
- Try rebuilding the container: "Dev Containers: Rebuild Container"

#### Missing packages or tools
- The post-create script should install everything needed
- If something is missing, you can manually install it or update the script

#### Azure authentication issues
- Make sure you're logged into Azure CLI: `az login`
- Check your environment variables in `.env`
- Verify your Azure credentials have the necessary permissions

### Extensions Included

The devcontainer automatically installs:
- C# and .NET tools
- Bicep language support
- Azure resource management tools
- Docker support
- GitHub integration
- Code quality tools

### Performance Tips

- Use the built-in terminal for better performance
- File watching is optimized for the container environment
- Hot reload is enabled for both backend and frontend projects