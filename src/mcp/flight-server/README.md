fastmcp run main.py:mcp --transport http --port 9000

az account get-access-token --resource api://<your-app-client-id> --query accessToken -o tsv

npx @modelcontextprotocol/inspector