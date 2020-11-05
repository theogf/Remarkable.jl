 abstract type RemarkableObject end

@with_kw struct Document <: RemarkableObject
    ID::String = string(uuid4())
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobURLGet::String = ""
    BlobURLGetExpires::String = string(DateTime(0)) * "Z"
    BlobURLPut::String = ""
    BlobURLPutExpires::String = string(DateTime(0)) * "Z"
    ModifiedClient::String = string(DateTime(now(UTC))) * "Z"
    VissibleName::String = "unknown"
    CurrentPage::Int = 1
    Bookmarked::Bool = false
    Type::String = "DocumentType"
    Parent::String = ""
end

@with_kw struct Collection <: RemarkableObject
    ID::String = string(uuid4())
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobURLGet::String = ""
    BlobURLGetExpires::String = string(DateTime(0))
    BlobURLPut::String = ""
    BlobURLPutExpires::String = string(DateTime(0)) 
    ModifiedClient::String = string(DateTime(now(UTC))) * "Z"
    VissibleName::String = "unknown"
    CurrentPage::Int = 0
    Bookmarked::Bool = false
    Type::String = "CollectionType"
    Parent::String = ""
    objects::Vector{RemarkableObject} = RemarkableObject[]
end

Document(dict::Dict{String, Any}) = Document(;Dict(Symbol(key)=>value for (key, value) in dict)...)
Collection(dict::Dict{String, Any}) = Collection(;Dict(Symbol(key)=>value for (key, value) in dict)...)

Base.getindex(c::Collection, i::Int) = c.objects[i]
Base.iterate(c::Collection, state) = iterate(c.objects, state)
Base.iterate(c::Collection) = iterate(c.objects)
Base.length(c::Collection) = length(c.objects)

AbstractTrees.children(::Document) = ()
AbstractTrees.children(c::Collection) = c.objects

AbstractTrees.printnode(io::IO, d::Document) = print(io, d.VissibleName)
AbstractTrees.printnode(io::IO, c::Collection) = print(io, c.VissibleName)

function create_tree(docs::AbstractVector{<:RemarkableObject})
    root = Collection(ID = "", VissibleName = "Root")
    push!(root.objects, Collection(ID = "Trash", VissibleName = "Trash"))
    update_obj!(root, docs) # Recursive loop on documents
    return root
end

function update_obj!(col::Collection, docs)
    for doc in docs
        if doc.Parent == col.ID
            update_obj!(doc, docs)
            push!(col.objects, doc)
        end
    end
end

update_obj!(::Document, ::Any) = nothing

function obj_to_dict(doc::Document)
    dict = type2dict(doc)
    return Dict(string(key)=>value for (key, value) in dict)
end

function obj_to_dict(col::Collection)
    dict = type2dict(col)
    delete!(dict, :objects)
    return Dict(string(key)=>value for (key, value) in dict)
end