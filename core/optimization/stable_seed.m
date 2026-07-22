function seed = stable_seed(master_seed, label)
%STABLE_SEED Derive a repeatable positive seed from a readable case label.
validateattributes(master_seed, {'numeric'}, {'scalar','integer','positive'});
bytes = uint8(char(label));
hash = uint32(mod(master_seed, 2^32-1));
for k = 1:numel(bytes)
    hash = bitxor(hash, uint32(bytes(k)));
    hash = uint32(mod(uint64(hash)*uint64(16777619), uint64(2^32-1)));
end
seed = double(mod(hash, uint32(2^31-2))) + 1;
end
