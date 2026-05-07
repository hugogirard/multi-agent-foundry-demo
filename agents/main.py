from dotenv import load_dotenv
from azure.identity import AzureCliCredential
from pathlib import Path
import json
import os
import requests


def main():
    load_dotenv(override=True)

    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    model = os.environ["AZURE_OPENAI_MODEL"]
    mcp_server_url = os.environ["MCP_SERVER_URL"]
    api_version = "2025-11-15-preview"

    # Load JSON agent definition and inject runtime values
    path = Path(__file__).parent / "definitions/flight-agent.json"
    with path.open("r") as f:
        agent_def = json.load(f)

    agent_def["definition"]["model"] = model
    for tool in agent_def["definition"].get("tools", []):
        if tool.get("type") == "mcp":
            tool["server_url"] = mcp_server_url
    agent_name = agent_def["name"]

    # Get bearer token
    credential = AzureCliCredential()
    token = credential.get_token("https://ai.azure.com/.default").token
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    # Check if agent already exists
    get_url = f"{endpoint}/agents/{agent_name}?api-version={api_version}"
    get_response = requests.get(get_url, headers=headers)

    if get_response.status_code == 200:
        # Agent exists — create a new version
        current = get_response.json()
        current_version = current["versions"]["latest"]["version"]
        print(f"Agent '{agent_name}' exists (version {current_version}). Creating new version...")

        version_url = f"{endpoint}/agents/{agent_name}/versions?api-version={api_version}"
        response = requests.post(version_url, headers=headers, json={"definition": agent_def["definition"]})
    else:
        # Agent does not exist — create it
        print(f"Agent '{agent_name}' not found. Creating...")

        create_url = f"{endpoint}/agents?api-version={api_version}"
        response = requests.post(create_url, headers=headers, json=agent_def)

    print(f"Status: {response.status_code}")
    print(json.dumps(response.json(), indent=2))


if __name__ == "__main__":
    main()
