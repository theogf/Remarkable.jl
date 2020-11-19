module Remarkable
using HTTP
using JSON
using ZipFile
using Dates
using Crayons
using Parameters: @with_kw, type2dict
using UUIDs: uuid4
using AbstractTrees: AbstractTrees, print_tree
export  RemarkableClient,
        list_items,
        get_item,
        delete_item!,
        create_folder!,
        download_pdf,
        upload_pdf!
export print_tree

include("const.jl")
include("client.jl")
include("documents.jl")
include("api.jl")

end