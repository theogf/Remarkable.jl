@with_kw struct Document
    ID::String
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobUrlGet::String = ""
    BlobUrlGetExpire::Date = Date(0)
    BlobURLPut::String = ""
    BlobURLPutExpires::Date = Date(0)
    ModifiedClient::Date = Date(0)
    VissibleName::String = "unknown"
    CurrentPage::Int = 1
    Bookmarked::Bool = false
    Parent::String = ""
end

@with_kw struct Collection
    ID::String
    Version::Int = 1
    Message::String = ""
    Success::Int = true
    BlobUrlGet::String = ""
    BlobUrlGetExpire::Date = Date(0)
    BlobURLPut::String = ""
    BlobURLPutExpires::Date = Date(0)
    ModifiedClient::Date = Date(0)
    VissibleName::String = "unknown"
    CurrentPage::Int = 1
    Bookmarked::Bool = false
    Parent::String = ""
end