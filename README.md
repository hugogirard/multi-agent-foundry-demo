```
az ad sp create-for-rbac --name "multi-agent-foundry-demo" --role Owner --scopes subscriptions/<SUBSCRIPTION_ID>
```

```
{
  "appId": "xxx-xxxx-xxxxx-xxxxx",
  "displayName": "multi-agent-foundry-demo",
  "password": "xxx-xxxx-xxxxx-xxxxx",
  "tenant": "xxx-xxxx-xxxxx-xxxxx"
}
```