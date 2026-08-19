from dotenv import load_dotenv
from azure.identity import AzureCliCredential
from pathlib import Path
import json
import os
import time
import requests

AGENTS = [
    {"definition": "definitions/flight-agent.json", "mcp_url_env": "MCP_FLIGHT_SERVER_URL", "output_key": "flight_agent_version"},
    {"definition": "definitions/hotel-agent.json", "mcp_url_env": "MCP_HOTEL_SERVER_URL", "output_key": "hotel_agent_version"},
]


def deploy_agent(endpoint, api_version, headers, agent_def, agent_name):
    version_url = f"{endpoint}/agents/{agent_name}/versions?api-version={api_version}"
    version_payload = {"definition": agent_def["definition"]}

    response = None
    for attempt in range(3):
        try:
            response = requests.post(version_url, headers=headers, json=version_payload, timeout=120)
        except requests.RequestException as exc:
            print(f"  Attempt {attempt + 1} failed with request error: {exc}")
            response = None

        if response is not None and response.status_code in (200, 201):
            break

        if response is None or response.status_code not in (404, 409, 429, 500, 502, 503, 504) or attempt == 2:
            break

        print(f"  Attempt {attempt + 1} failed with {response.status_code}. Retrying in 2 seconds...")
        time.sleep(2)

    return response


def main():
    load_dotenv(override=True)

    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    model = os.environ["AZURE_OPENAI_MODEL"]
    api_version = "2025-11-15-preview"

    credential = AzureCliCredential()
    token = credential.get_token("https://ai.azure.com/.default").token
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    github_output = os.environ.get("GITHUB_OUTPUT")
    failed = False

    for agent_config in AGENTS:
        mcp_server_url = os.environ[agent_config["mcp_url_env"]]

        path = Path(__file__).parent / agent_config["definition"]
        with path.open("r") as f:
            agent_def = json.load(f)

        agent_def["definition"]["model"] = model
        for tool in agent_def["definition"].get("tools", []):
            if tool.get("type") == "mcp":
                tool["server_url"] = mcp_server_url
        agent_name = agent_def["name"]

        print(f"\n{'='*60}")
        print(f"Deploying agent: {agent_name}")
        print(f"{'='*60}")

        response = deploy_agent(endpoint, api_version, headers, agent_def, agent_name)

        if response is None:
            print(f"  Status: request failed (empty response)")
            failed = True
            continue

        print(f"  Status: {response.status_code}")

        try:
            response_body = response.json()
        except ValueError:
            response_body = None

        if response_body is not None:
            print(json.dumps(response_body, indent=2))
            if github_output and "id" in response_body:
                with open(github_output, "a") as fh:
                    fh.write(f"{agent_config['output_key']}={response_body['id']}\n")
        elif response.text:
            print(response.text)
        else:
            print("  (empty response body)")

        if response.status_code >= 400:
            failed = True

    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
