abstract type RemarkableObject end

@with_kw struct Document <: RemarkableObject
    ID::String
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobURLGet::String = ""
    BlobURLGetExpires::String = string(Date(0))
    BlobURLPut::String = ""
    BlobURLPutExpires::String = string(Date(0))
    ModifiedClient::String = string(Date(0))
    VissibleName::String = "unknown"
    CurrentPage::Int = 1
    Bookmarked::Bool = false
    Type::String = "DocumentType"
    Parent::String = ""
end

@with_kw mutable struct Collection <: RemarkableObject
    ID::String
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobURLGet::String = ""
    BlobURLGetExpires::String = string(Date(0))
    BlobURLPut::String = ""
    BlobURLPutExpires::String = string(Date(0))
    ModifiedClient::String = string(Date(0))
    VissibleName::String = "unknown"
    CurrentPage::Int = 1
    Bookmarked::Bool = false
    Type::String = "CollectionType"
    Parent::String = ""
    objects::Vector{RemarkableObject} = RemarkableObject[]
end

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
    update_obj!(root, docs) # Recursive loop on documents
end

function update_obj!(col::Collection, docs)
    objects = RemarkableObject[]
    for doc in docs
        if doc.Parent == col.ID
            update_obj!(doc, docs)
            @info doc.VissibleName, col.VissibleName
            push!(objects, doc)
        end
    end
    col.objects = objects
end

update_obj!(::Document, docs) = nothing