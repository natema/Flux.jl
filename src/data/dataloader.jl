# Adapted from Knet's src/data.jl (author: Deniz Yuret)

struct DataLoader
    data
    batchsize::Int
    nobs::Int
    partial::Bool
    imax::Int
    indices::Vector{Int}
    shuffle::Bool
end

"""
    DataLoader(data; batchsize=1, shuffle=false, partial=true)
    
An object that iterates over mini-batches of `data`, each mini-batch containing `batchsize` observations
(except possibly the last one). 

Takes as input a data tensors or a tuple of one or more such tensors. 
The last dimension in each tensor is considered to be the observation dimension. 

If `shuffle=true`, shuffles the observations each time iterations are re-started.
If `partial=false`, drops the last mini-batch if it is smaller than the batchsize.

The original data is preserved in the `data` field of the DataLoader. 

Example usage:

    Xtrain = rand(10, 100)
    train_loader = DataLoader(Xtrain, batchsize=2) 
    # iterate over 50 mini-batches of size 2
    for x in train_loader
        @assert size(x) == (10, 2)
        ...
    end

    train_loader.data   # original dataset

    # similar but yielding tuples
    train_loader = DataLoader((Xtrain,), batchsize=2) 
    for (x,) in train_loader
        @assert size(x) == (10, 2)
        ...
    end

    Xtrain = rand(10, 100)
    Ytrain = rand(100)
    train_loader = DataLoader((Xtrain, Ytrain), batchsize=2, shuffle=true) 
    for epoch in 1:100
        for (x, y) in train_loader
            @assert size(x) == (10, 2)
            @assert size(y) == (2,)
            ...
        end
    end

    # train for 10 epochs
    using IterTools: ncycle 
    Flux.train!(loss, ps, ncycle(train_loader, 10), opt)
"""
function DataLoader(data; batchsize=1, shuffle=false, partial=true)
    batchsize > 0 || throw(ArgumentError("Need positive batchsize"))
    
    n = _nobs(data) 
    if n < batchsize
        @warn "Number of observations less than batchsize, decreasing the batchsize to $n"
        batchsize = n
    end
    imax = partial ? n : n - batchsize + 1
    ids = 1:min(n, batchsize)
    DataLoader(data, batchsize, n, partial, imax, [1:n;], shuffle)
end

@propagate_inbounds function Base.iterate(d::DataLoader, i=0)     # returns data in d.indices[i+1:i+batchsize]
    i >= d.imax && return nothing
    if d.shuffle && i == 0
        shuffle!(d.indices)
    end
    nexti = min(i + d.batchsize, d.nobs)
    ids = d.indices[i+1:nexti]
    batch = _getobs(d.data, ids)
    return (batch, nexti)
end

function Base.length(d::DataLoader)
    n = d.nobs / d.batchsize
    d.partial ? ceil(Int,n) : floor(Int,n)
end

_nobs(data::AbstractArray) = size(data)[end]

function _nobs(data::Tuple)
    length(data) > 0 || throw(ArgumentError("Need at least one data input"))
    n = _nobs(data[1])
    if !all(x -> _nobs(x) == n, data[2:end])
        throw(DimensionMismatch("All data should contain same number of observations"))
    end
    return n
end

_getobs(data::AbstractArray, i) = data[(Base.Colon() for _=1:ndims(data)-1)..., i]
_getobs(data::Tuple, i) = ((_getobs(x, i) for x in data)...,)
