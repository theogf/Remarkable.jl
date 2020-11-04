module Remarkable
using HTTP
using JSON
using ZipFile
using Dates
using Parameters
export RemarkableClient

const STORAGE_API = Ref("https://document-storage-production-dot-remarkable-production.appspot.com")
const SERVICE_DISCOVERY_API = "https://service-manager-production-dot-remarkable-production.appspot.com"
const STORAGE_URL = "/service/json/1/document-storage"
const AUTH_API = "https://my.remarkable.com"
const NEW_TOKEN = "/token/json/2/user/new"
const ITEM_LIST = "/document-storage/json/2/docs"

include("documents.jl")


mutable struct RemarkableClient
    token::String
    function RemarkableClient(token::String="")
        new(token)
    end
end

set_token!(c::RemarkableClient, tok::String) = c.token = tok

function dict_to_query(d::Dict)
    query = ""
    for (key, value) in d
        query *= "$(key)=$(value)&"
    end
    query = query[1:end-1]
end

function request(c::RemarkableClient, verb::String, url::String, options::Dict=Dict())
    options = merge(options, Dict("Authorization" => "Bearer $(c.token)"))
    return HTTP.request(verb,
                        url,
                        options;
                        query = haskey(options, "query") ? dict_to_query(options["query"]) : nothing
                    )
end

struct RemarkableAPI
end

function register()

end

function register(::RemarkableAPI, code::String)
    error("not finished yet")
    data = Dict(
            "code" => code,
            "deviceDesc" => "desktop-windows",
            "deviceID" => string(uuid4())
        )
    @info "Registering device"
    # TDO should send a JSON
    respose = HTTP.request(
                    "POST",
                    AUTH_API,
                    data
    )
    token = String(response.body)
    @info "Token : $token"
    #TODO write it in a file somewhere
    return token
end

function init(api::RemarkableAPI, token::String)
    refresh_token(api, token)
    discover_storage(api)
end

function refresh_token!(client::RemarkableClient)
    @info "Refreshing the auth token"
    response = request(client, "POST", AUTH_API * NEW_TOKEN)
    new_token = String(response.body)
    set_token!(client, new_token)
    return new_token
end

function list_items(client::RemarkableClient)
    @info "Listing all items"
    response = request(client, "GET", STORAGE_API[] * ITEM_LIST)
    return JSON.parse(String(response.body))
end

function get_item(client::RemarkableClient, id::String, download::Bool = false)
    query = Dict("doc" => id)
    if download
        query["withBlob"] = "true"
    end
    @info "Listing item"
    response = request(client,
                    "GET", 
                    STORAGE_API[] * ITEM_LIST,
                    Dict("query" => query))
    item = JSON.parse(String(response.body))
    return first(item)
end

function download_document(client::RemarkableClient, id::String)
    item = get_item(client, id, true)
    url = item["BlobURLGet"]

    @info "Downloading data"
    response = request(client, "GET", url)
    return response
end

function download_document(client::RemarkableClient, id::String, path_target::String)
    file_path = joinpath(path_target, id * ".zip")
    response = download_document(client, id)
    write(file_path, response.body)
end

function discover_storage(client::RemarkableClient)
    @info "Discovering storage host"
    response = request(client,
                    "GET",
                    SERVICE_DISCOVERY_API * STORAGE_URL,
                    Dict(
                        "query" => Dict(
                            "environment" => "production",
                            "group" => "auth0|5a68dc51cb30df3877a1d7c4", # Legacy from RemarkableAPI
                            "apiVer" => 2,
                        )
                    )
                )
    data = JSON.parse(String(response.body))
    if isempty(data) || data["Status"] != "OK"
        error("Service discovery failed")
    end
    STORAGE_API[] = "https://" * data["Host"]
end
end
