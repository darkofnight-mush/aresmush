import { _ as _applyDecoratedDescriptor, a as _initializerDefineProperty } from '../_rollupPluginBabelHelpers-e795903d.js';
import { equal, mapBy, sort } from '@ember/object/computed';
import Service from '@ember/service';
import { isNone, typeOf } from '@ember/utils';
import { assert, warn } from '@ember/debug';
import { computed, get, set, setProperties } from '@ember/object';
import { classify } from '@ember/string';
import { A } from '@ember/array';
import FlashObject from '../flash/object.js';
import objectWithout from '../utils/object-without.js';
import { getOwner } from '@ember/application';
import flashMessageOptions from '../utils/flash-message-options.js';
import getWithDefault from '../utils/get-with-default.js';

var _dec, _dec2, _dec3, _class, _descriptor, _descriptor2, _descriptor3;
let FlashMessagesService = (_dec = equal('queue.length', 0).readOnly(), _dec2 = mapBy('queue', '_guid').readOnly(), _dec3 = sort('queue', function (a, b) {
  if (a.priority < b.priority) {
    return 1;
  } else if (a.priority > b.priority) {
    return -1;
  }
  return 0;
}).readOnly(), (_class = class FlashMessagesService extends Service {
  constructor() {
    super(...arguments);
    _initializerDefineProperty(this, "isEmpty", _descriptor, this);
    _initializerDefineProperty(this, "_guids", _descriptor2, this);
    _initializerDefineProperty(this, "arrangedQueue", _descriptor3, this);
    this._setDefaults();
    this.queue = A();
  }
  willDestroy() {
    super.willDestroy(...arguments);
    this.clearMessages();
  }
  add(options = {}) {
    this._enqueue(this._newFlashMessage(options));
    return this;
  }
  clearMessages() {
    const flashes = this.queue;
    if (isNone(flashes)) {
      return;
    }
    flashes.forEach(flash => flash.destroyMessage());
    flashes.clear();
    return this;
  }
  registerTypes(types = A()) {
    types.forEach(type => this._registerType(type));
    return this;
  }
  peekFirst() {
    return this.queue.firstObject;
  }
  peekLast() {
    return this.queue.lastObject;
  }
  getFlashObject() {
    const errorText = 'A flash message must be added before it can be returned';
    assert(errorText, this.queue.length);
    return this.peekLast();
  }
  _newFlashMessage(options = {}) {
    assert('The flash message cannot be empty when preventDuplicates is enabled.', this.defaultPreventDuplicates ? options.message : true);
    assert('The flash message cannot be empty when preventDuplicates is enabled.', options.preventDuplicates ? options.message : true);
    const flashService = this;
    const allDefaults = getWithDefault(this, 'flashMessageDefaults', {});
    const defaults = objectWithout(allDefaults, ['types', 'preventDuplicates']);
    const flashMessageOptions = Object.assign({}, defaults, {
      flashService
    });
    for (let key in options) {
      const value = get(options, key);
      const option = this._getOptionOrDefault(key, value);
      set(flashMessageOptions, key, option);
    }
    return FlashObject.create(flashMessageOptions);
  }
  _getOptionOrDefault(key, value) {
    const defaults = getWithDefault(this, 'flashMessageDefaults', {});
    const defaultOption = get(defaults, key);
    if (typeOf(value) === 'undefined') {
      return defaultOption;
    }
    return value;
  }
  get flashMessageDefaults() {
    const config = getOwner(this).resolveRegistration('config:environment');
    const overrides = getWithDefault(config, 'flashMessageDefaults', {});
    return flashMessageOptions(overrides);
  }
  _setDefaults() {
    const defaults = getWithDefault(this, 'flashMessageDefaults', {});
    for (let key in defaults) {
      const classifiedKey = classify(key);
      const defaultKey = `default${classifiedKey}`;
      set(this, defaultKey, defaults[key]);
    }
    this.registerTypes(getWithDefault(this, 'defaultTypes', A()));
  }
  _registerType(type) {
    assert('The flash type cannot be undefined', type);
    this[type] = (message, options = {}) => {
      const flashMessageOptions = Object.assign({}, options);
      setProperties(flashMessageOptions, {
        message,
        type
      });
      return this.add(flashMessageOptions);
    };
  }
  _hasDuplicate(guid) {
    return this._guids.includes(guid);
  }
  _enqueue(flashInstance) {
    const instancePreventDuplicates = flashInstance.preventDuplicates;
    const preventDuplicates = typeof instancePreventDuplicates === 'boolean' ?
    // always prefer instance option over global option
    instancePreventDuplicates : this.defaultPreventDuplicates;
    if (preventDuplicates) {
      const guid = flashInstance._guid;
      if (this._hasDuplicate(guid)) {
        warn('Attempting to add a duplicate message to the Flash Messages Service', false, {
          id: 'ember-cli-flash.duplicate-message'
        });
        return;
      }
    }
    return this.queue.pushObject(flashInstance);
  }
}, (_descriptor = _applyDecoratedDescriptor(_class.prototype, "isEmpty", [_dec], {
  configurable: true,
  enumerable: true,
  writable: true,
  initializer: null
}), _descriptor2 = _applyDecoratedDescriptor(_class.prototype, "_guids", [_dec2], {
  configurable: true,
  enumerable: true,
  writable: true,
  initializer: null
}), _descriptor3 = _applyDecoratedDescriptor(_class.prototype, "arrangedQueue", [_dec3], {
  configurable: true,
  enumerable: true,
  writable: true,
  initializer: null
}), _applyDecoratedDescriptor(_class.prototype, "flashMessageDefaults", [computed], Object.getOwnPropertyDescriptor(_class.prototype, "flashMessageDefaults"), _class.prototype)), _class));

export { FlashMessagesService as default };
//# sourceMappingURL=flash-messages.js.map
