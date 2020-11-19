"""
    RemarkableClient(token::String)

Client used for identification. Simply contains the authentification token
"""
struct RemarkableClient
    token::Ref{String}
    function RemarkableClient(token::String=""; path_to_token::String=pwd())
        if isempty(token) && !isfile(joinpath(path_to_token, ".token"))
            error(
                """
                    You did not give a token or a path to .token file to `RemarkableClient`.
                    If you don't know what I am talking about run `register()`.
                    If you have a code, e.g "axervi", run `register(code)` to get a token.
                """)
        elseif isfile(joinpath(path_to_token, ".token"))
            token = String(read(joinpath(path_to_token, ".token")))
        end
        client = new(Ref(token))
        refresh_token!(client) # Get a new authentification
        discover_storage(client)
        return client
    end
end

set_token!(c::RemarkableClient, tok::String) = c.token[] = tok
token(c) = c.token[]

"""
    refresh_token(client::RemarkableClient) -> token

Before running operations the token needs to be refreshed, `refresh_token!`
does just that!
"""
function refresh_token!(client::RemarkableClient; kwargs...)
    @info "Refreshing the auth token"
    body = HTTP.request(client, "POST", AUTH_API * NEW_TOKEN; kwargs...)
    new_token = String(body)
    set_token!(client, new_token)
    return new_token
end

"""
    discover_storage(client) -> String

Check that the storage URL is still the right one and update it if needed
"""
function discover_storage(client::RemarkableClient; kwargs...)
    @info "Discovering storage host"
    body = HTTP.request(client,
                    "GET",
                    SERVICE_DISCOVERY_API * STORAGE_URL;
                    query = Dict(
                            "environment" => "production",
                            "group" => "auth0|5a68dc51cb30df3877a1d7c4", # Legacy from RemarkableAPI
                            "apiVer" => 2,
                        ),
                    kwargs...
                )
    data = JSON.parse(String(body))
    if isempty(data) || data["Status"] != "OK"
        error("Service discovery failed")
    end
    STORAGE_API[] = "https://" * data["Host"]
    return STORAGE_API[]
end



"""
    dict_to_query(d::Dict) -> String

From a dictionary creates a string as :
"key1=value1&key2=value2..."
"""
function dict_to_query(d::Dict)
    query = ""
    for (key, value) in d
        query *= "$(key)=$(value)&"
    end
    query = query[1:end-1]
end

"""
    request(client, verb, url, headers, body; kwargs...) -> body

Workhorse to communicate with the Remarkable servers.
It is behaving like `HTTP.request`, except that it automatically uses
the identification token in every request.
"""
function HTTP.request(client::RemarkableClient, verb::String, url::String, headers::Dict=Dict(), body=""; kwargs...)
    merge!(headers, Dict("Authorization" => "Bearer $(token(client))"))
    response = HTTP.request(verb,
                        url,
                        headers,
                        body;
                        kwargs...
            )
    body = response.body
    # if isempty(body)
    #     error("Returned empty body message")
    # end
    return body
end

"""
    storage_request(client, verb, url, obj, kwargs...)

Specific request related to storage. Converts `obj` to a JSON string,
and automatically transform the body in another JSON.
"""
function storage_request(client::RemarkableClient, verb::String, url::String, obj::Dict; kwargs...)
    body = request_json(client, verb, STORAGE_API[] * ITEM * url, obj; kwargs...)
    data = first(JSON.parse(String(body)))
    if !data["Success"]
        error(data["Message"])
    end
    return data
end

function request_json(client::RemarkableClient, verb::String, url::String, data::Dict, headers::Dict=Dict(); kwargs...)
    return HTTP.request(client, verb, url, headers, JSON.json([data]); kwargs...)
end