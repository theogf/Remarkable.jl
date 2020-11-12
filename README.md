# Remarkable.jl

API for the ReMarkable cloud. Based on [`RemarkableAPI`](https://github.com/splitbrain/ReMarkableAPI), you can find a detailed API documentation in its [wiki](https://github.com/splitbrain/ReMarkableAPI/wiki).

## Setup

To use the API you first need to register your device:
Get a authentification code on [https://my.remarkable.com/connect/desktop] and call `register("your code here")`. This will create a token and save it as `.token` in your current folder (you can change this by calling `register("code", path_to_token = "/home/my/path")`.

Once this is done create a client with `RemarkableClient()` which will by default look for a `.token` in your folder or take directly a token (check the docs!)

## Doing cool stuff!

From there you can :
- Access your data! `data = list_items(client)` will return a `Collection` containing all documents and sub folders. You can visualize nicely the structure by calling `print_tree(data)`.
- Get a specific item! You can directly parse the `data` and select the item of you interest. If you know your item `ID` you can also do it via `get_item(client, ID)`.
- Download an item! Just call `download(client, item, local_path)`.
This will download the item as a `.zip` file. If you just want the `.pdf`, `download_pdf` is also possible.
- Upload a pdf! Call `upload_pdf!(client, path_to_pdf, pdf_name, parent)` where parent is the folder ID or a `Collection`.
- Delete an item! Call `delete_item!(client, item)` and you can say good-bye!

Everything is done with `HTTP.request`, you can pass any `request` keyword argument to all functions (for example setting `verbose=2`) (only avoid `query`)

## A small demo

Here is a small script getting a list of file, downloading one, renaming it and reuploading it :

```julia
client = RemarkableClient()
items = list_items(client)
print_tree(items) |> display
#= 
Root
├─ Quick sheets
├─ SVGD Integration
├─ Books
│  └─ entropy-22-01100
├─ Teaching
│  └─ PML 20/21
├─ Derivations
=#
item = items[3][1] # entropy-22...
file_path = download_pdf(client, item, pwd())
mv(file_path, "new_name.pdf")
upload_pdf!(client, "new_name.pdf", "Entropy Book.pdf", items[3]) # We reupload in the same location
delete_item!(client, item) # we delete the old item
```