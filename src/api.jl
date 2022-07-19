
## Token and registration related API

"""
    register(code::String) -> String
    register() -> String

Create a new authentification token from a code obtained on https://my.remarkable.com/connect/desktop
If a code is not provided a tutorial is given.
"""
function register(code::String; path_to_token::String="", kwargs...)
    data = Dict(
        "code" => code, "deviceDesc" => "desktop-windows", "deviceID" => string(uuid4())
    )
    @info "Registering device"
    response = HTTP.request("POST", AUTH_API * NEW_DEVICE, [], JSON.json(data); kwargs...)
    token = String(response.body)
    @info "Token : $token"
    if isempty(path_to_token)
        path_to_token = pwd()
    end
    write(joinpath(path_to_token, ".remarkable_jl_token"), token)
    @info "Token saved at $(joinpath(path_to_token))"
    return nothing
end

function register()
    @warn """
        Hi, to use this API you first need to register this device.
        To do so go to https://my.remarkable.com/device/desktop/connect and ask for a new code!
        Be careful you have 5 min to enter this code!
        Once you have it run `Remarkable.register(code)` (where `code` is a `String`).
        It will return your authentification token and also save your token in a local file.
        """
end

## Items accessors

"""
    list_items(client::RemarkableClient) -> Collection

Return a `Collection` of all `Document`s and `Collection` present on the server
You can visualize them nicely via `print_tree`
"""
function list_items(client::RemarkableClient; kwargs...)
    @info "Listing all items"
    @show link = BASE_URL[] * API_DOWNLOAD
    body = HTTP.request(client, "POST", BASE_URL[] * API_DOWNLOAD; query = Dict(
        "http_method" => "GET",
        "relative_path" => "root",
    ))

    @show String(body)
    body = HTTP.request(client, "GET", STORAGE_API[] * ITEM_LIST; kwargs...)
    items = JSON.parse(String(body))
    docs = RemarkableObject[]
    for item in items
        item = Dict(Symbol(key) => value for (key, value) in item)
        if item[:Type] == "DocumentType"
            doc = Document(; item...)
            push!(docs, doc)
        elseif item[:Type] == "CollectionType"
            collec = Collection(; item...)
            push!(docs, collec)
        end
    end
    return create_tree(docs)
end

"""
    get_item(client, id::String, download = false)
    get_item(client, id::RemarkableObject, download = false)

Return a `RemarkableObject` given an ID or an existing `RemarkableObject`,
using `download=true` will give the `BlobURLGet` to download the files
"""
function get_item(client::RemarkableClient, id::String, download::Bool=false; kwargs...)
    return get_item(client, Document(; ID=id), download; kwargs...)
end

function get_item(
    client::RemarkableClient, doc::RemarkableObject, download::Bool=false; kwargs...
)
    query = Dict("doc" => doc.ID)
    if download
        query["withBlob"] = "true"
    end
    @info "Listing item"
    body = HTTP.request(client, "GET", STORAGE_API[] * ITEM_LIST; query=query, kwargs...)
    item = JSON.parse(String(body))
    return Document(first(item))
end

## Item modificators 

"""
    delete_item!(client, id::String)
    delete_item!(client, obj::remarkable)

Delete the object from your collection (online)
"""
function delete_item!(client::RemarkableClient, id::String; kwargs...)
    return delete_item!(client, Document(; ID=id); kwargs...)
end

function delete_item!(client::RemarkableClient, obj::RemarkableObject; kwargs...)
    @info "Deleting item `$(title(obj))`"
    return storage_request(client, "PUT", "delete", obj_to_dict(obj); kwargs...)
end

"""
    update_metadata!(client, obj::RemarkableObject) -> 

Update the metadata of an object, can be used to modify a file or create a 
Collection
"""
function update_metadata!(client::RemarkableClient, obj::RemarkableObject; kwargs...)
    @info "Updating item metadata `$(title(obj))`"
    return storage_request(client, "PUT", UPDATE_STATUS, obj_to_dict(obj); kwargs...)
end

"""
    create_folder!(client, name::String, parent::String="") ->

Create a folder (Collection) in `parent` (root by default)
"""
function create_folder!(
    client::RemarkableClient, name::String, parent::String=""; kwargs...
)
    item = Collection(; Parent=parent, VissibleName=name)
    @info "Creating folder $name"
    res = update_metadata!(client, item; kwargs...)
    return Collection(res)
end

## Download files

"""
    download_document(client, id::String, [path_target::String]) -> ZipFile Body
    download_document(client, doc::Document, [path_target::String]) -> Zipfile Body

Download a document object with given id/doc.
The document is always given as a `ZipFile` and can be saved via `write(filepath, body)`
if `path_target` is given, the zip file is automatically written and named.
"""
function Base.download(client::RemarkableClient, id::String; kwargs...)
    return download(client, Document(; ID=id); kwargs...)
end

function Base.download(client::RemarkableClient, doc::Document; kwargs...)
    doc = get_item(client, doc.ID, true)
    @info "Downloading data"
    return HTTP.request(client, "GET", doc.BlobURLGet; kwargs...)
end

function Base.download(client::RemarkableClient, id::String, path_target::String; kwargs...)
    return download_document(client, Document(; ID=id), path_target; kwargs...)
end

function Base.download(
    client::RemarkableClient, doc::Document, path_target::String; kwargs...
)
    file_name =
        isempty(title(doc)) ? doc.ID : (ispdf(doc) ? title(doc)[1:(end - 4)] : title(doc))
    file_path = joinpath(path_target, file_name * ".zip")
    body = download(client, doc; kwargs...)
    write(file_path, body)
    @info "File downloaded at $(file_path)"
    return file_path
end

function download_pdf(
    client::RemarkableClient, doc::Document, path_target::String; kwargs...
)
    file_path = download(client, doc, path_target; kwargs...)
    file_name =
        isempty(title(doc)) ? doc.ID : (ispdf(doc) ? title(doc)[1:(end - 4)] : title(doc))
    z = ZipFile.Reader(file_path)
    for f in z.files
        if endswith(f.name, ".pdf")
            write(joinpath(path_target, file_name * ".pdf"), f)
            @info "Extracted $(file_name).pdf"
            return joinpath(path_target, file_name * ".pdf")
        end
    end
end

## Upload files

"""
    create_upload_request(client, doc::Document=Document()) -> Document

Create a request to upload a document with a given id.
"""
function create_upload_request(
    client::RemarkableClient, doc::Document=Document(); kwargs...
)
    @info "Creating upload request"
    data = storage_request(client, "PUT", "upload/request", obj_to_dict(doc); kwargs...)
    if isempty(data["BlobURLPut"])
        error("Failed to get URL for upload")
    end
    return Document(doc; BlobURLPut=data["BlobURLPut"])
end

"""
    upload_document!(client, obj::RemarkableObject, zip) -> RemarkableObject

Upload `zip` file (actual zip file) with metadata from obj
"""
function upload_document!(
    client::RemarkableClient, obj::RemarkableObject, zipfile; kwargs...
)
    obj = create_upload_request(client, obj; kwargs...)
    @info "Uploading data"
    body = HTTP.request(client, "PUT", obj.BlobURLPut, Dict(), zipfile; kwargs...)
    item = update_metadata!(client, obj)
    return item
end

"""
    upload_pdf!(client, pdf_path::String, pdf_name::String = basename(pdf_path), parent)

Create a document for the given pdf and upload it.
"""
function upload_pdf!(
    client::RemarkableClient,
    pdf_path::String,
    pdf_name::String=basename(pdf_path),
    parent::String="";
    kwargs...,
)
    return upload_pdf!(client, read(pdf_path), pdf_name, parent; kwargs...)
end

function upload_pdf!(
    client::RemarkableClient, pdf, pdfname::String, parent::String=""; kwargs...
)
    doc = Document(; Parent=parent, VissibleName=pdfname)
    ## Create the ZIP file here with ZipFile
    tmpdir = mktempdir()
    tmpfile = joinpath(tmpdir, doc.ID * ".zip")
    zip = ZipFile.Writer(tmpfile)

    pdffile = ZipFile.addfile(zip, doc.ID * ".pdf")
    write(pdffile, pdf)

    pagedata = ZipFile.addfile(zip, doc.ID * ".pagedata")
    write(pagedata, "")

    content = ZipFile.addfile(zip, doc.ID * ".content")
    json_content = Dict(
        "extraMetaData" => Dict(),
        "fileType" => "pdf",
        "lastOpenedPage" => 0,
        "lineHeight" => -1,
        "margins" => 100,
        "pageCount" => 0,
        "textScale" => 1,
        "transform" => Dict(),
    )
    write(content, JSON.json(json_content))

    close(zip)
    # zip = ZipFile.Reader(tmpfile)
    @info "Zip file temporarily saved at $(tmpfile)."
    return upload_document!(client, doc, read(joinpath(tmpfile)); kwargs...)
end
