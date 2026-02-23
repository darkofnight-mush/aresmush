import { get } from '@ember/object';

// This replicates Ember's deprecated `getWithDefault`.
// Note that, as in the original, `null` is considered a valid value and will
// not cause the function to return the default value.
function getWithDefault(objectInstance, key, defaultValue) {
  let value = get(objectInstance, key);
  if (value === undefined) {
    return defaultValue;
  }
  return value;
}

export { getWithDefault as default };
//# sourceMappingURL=get-with-default.js.map
