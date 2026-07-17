from dotenv import load_dotenv
from azure.identity import AzureCliCredential
from pathlib import Path
import json
import os
import time
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
    token = credential.get_token("https://cognitiveservices.azure.com/.default").token
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    version_url = f"{endpoint}/agents/{agent_name}/versions?api-version={api_version}"
    version_payload = {"definition": agent_def["definition"]}

    response = None
    for attempt in range(3):
        try:
            response = requests.post(version_url, headers=headers, json=version_payload, timeout=120)
        except requests.RequestException as exc:
            print(f"Attempt {attempt + 1} failed with request error: {exc}")
            response = None

        if response is not None and response.status_code in (200, 201):
            break

        if response is None or response.status_code not in (404, 409, 429, 500, 502, 503, 504) or attempt == 2:
            break

        print(f"Attempt {attempt + 1} failed with {response.status_code}. Retrying in 2 seconds...")
        time.sleep(2)

    if response is None:
        print("Status: request failed")
        print("(empty response body)")
        raise SystemExit(1)

    print(f"Status: {response.status_code}")

    try:
        response_body = response.json()
    except ValueError:
        response_body = None

    if response_body is not None:
        print(json.dumps(response_body, indent=2))

        # Write agent version to GITHUB_OUTPUT for CI consumption
        github_output = os.environ.get("GITHUB_OUTPUT")
        if github_output and "id" in response_body:
            with open(github_output, "a") as fh:
                fh.write(f"agent_version={response_body['id']}\n")
    elif response.text:
        print(response.text)
    else:
        print("(empty response body)")

    if response.status_code >= 400:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
