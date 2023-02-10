# secli
pure Bash CLI to manage SoftEther VPN Server using JSON-RPC

SoftEther server can be managed by JSON-RPC, but there was not a CLI to manage it from a Terminal.  
`secli` tries to be a SE server client written in Bash to manage a SE server.

## prerequisites
The CLI needs the following in order to function properly:  

- [Bash](https://www.gnu.org/software/bash/) v4.4 or higher
- [perl](https://www.perl.org/) 
- jq [project](https://stedolan.github.io/jq/), [download](https://stedolan.github.io/jq/)
- yq [project](https://github.com/mikefarah/yq), [download](https://github.com/mikefarah/yq/releases)
- some other Linux commands. e.g. printf, grep, etc

## CIL architecture
Unlink traditional Unix/Linux CLIs which all the functionalities are managed by options (i.e `--option`); `secli` uses **Pipeline Architecture**. 
This architecture helps to have:  
- software testability
- software modularity
- software extendability
- component/function reusability
- and more

[See Software Non-functional requirement](https://en.wikipedia.org/wiki/Non-functional_requirement).  


Thus `secli` does not follow traditional option based CLIs, as you might expect like bellow samples:

```bash
./secli --admin --admin-password <PASSWORD> --add-user --user-name XYZ --user-pass 123@XYZ --enable-policy vpn.example.com
```

And `secli` handles its functionality using pipe (**Name Pipe in Linux** == `|`). Here are examples

### Test (Test RPC function)

```
./secli.sh Test | ./secli.sh config -f sample.admin.yaml -t usa | ./secli.sh apply
{
    "result": {
        "Int64Value_u64": 0,
        "IntValue_u32": 0,
        "StrValue_str": "0",
        "UniStrValue_utf": ""
    },
    "jsonrpc": "2.0",
    "id": "rpc_call_id"
}
```

 - Test: the JSON-RPC for testing the server is up or no
 - config: add our server credentials to the JSON-RPC 
 - apply: send JSON-RPC of Test to server and use credentials for authentication


---

## JSON-RPCs have been added

 - `Test                 Test RPC function`
 - `GetServerInfo        Get server information`
 - `GetServerStatus      Get Current Server Status`
 - `CreateListener       Create New TCP Listener`
 - `EnumListener         Get List of TCP Listeners`
 - `DeleteListener       Delete TCP Listener`
 - `EnableListener       Enable / Disable TCP Listener`
 - `CreateUser           Create a user`
 - `SetUser              Change User Settings`
 - `GetUser              Get User Settings`
 - `DeleteUser           Delete a user`
 - `EnumUser             Get List of Users`
 - `EnumSession          Get List of Connected VPN Sessions`
 - `GetSessionStatus     Get Session Status`
 - `DeleteSession        Disconnect Session`

Others will be added gradually.  
You can ask/request for new JSON-RPC be added or contribute and send PR (Pull Request).  
[Here is the full list](https://github.com/SoftEtherVPN/SoftEtherVPN/tree/master/developer_tools/vpnserver-jsonrpc-clients).

