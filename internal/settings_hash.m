function digest = settings_hash(varargin)
%SETTINGS_HASH Stable 64-bit identifier for settings or source text.
% Approval gates and storage-only options are excluded because changing them
% does not change a numerical result or its scientific interpretation. This
% identifier is for reproducibility checks, not cryptographic security.
values = varargin;
bytes = uint8(jsonencode(values));
fnv = uint32(2166136261);
djb = uint32(5381);
modulus = uint64(2^32);
for k = 1:numel(bytes)
    fnv = bitxor(fnv,uint32(bytes(k)));
    fnv = uint32(mod(uint64(fnv)*uint64(16777619),modulus));
    djb = uint32(mod(uint64(djb)*uint64(33)+uint64(bytes(k)),modulus));
end
digest = lower([dec2hex(fnv,8) dec2hex(djb,8)]);
end
