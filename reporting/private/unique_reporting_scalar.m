function value = unique_reporting_scalar(values,description)
%UNIQUE_REPORTING_SCALAR Require one finite reporting value.
if numel(values) ~= 1 || ~isfinite(values)
    error('fa:PublicationSourceData', ...
        'Expected one finite value for %s.',description);
end
value = values(1);
end
